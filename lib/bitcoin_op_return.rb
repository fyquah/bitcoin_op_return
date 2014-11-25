require "shellwords"
require "json"

class String
  def shift! n
    n > 0 ? slice!(0..(n-1)) : ""
  end
end

module BitcoinOpReturn  
  class << self
    attr_accessor :bitcoind_cmd, :transaction_fee

    def create options
      send_address = options[:address].to_s
      send_amount = options[:amount].to_f
      metadata = options[:metadata].to_s
      testnet = !options[:testnet].nil?
      transaction_fee = options[:transaction_fee].to_f || self.transaction_fee

      # convert to hex where possible
      metadata = [ metadata ].pack("H*") if metadata =~ /\A([0-9A-Fa-f]{2})*\z/

      return { :error => "invalid address" } unless bitcoind("validateaddress", testnet, send_address)["isvalid"]
      return { :error => "metadata too long, limit is 75, recommended is 40 bytes" } if metadata.length > 75

      # get the unspent inputs
      unspent_inputs = bitcoind("listunspent", testnet, 0)
      return { :error => "unable to retrieve unspent inputs" } unless unspent_inputs.kind_of? Array

      unspent_inputs.each do |input|
        input["priority"] = input["amount"] * input["confirmations"]
      end

      unspent_inputs.sort! do |a, b|
        a = a["priority"]
        b = b["priority"]
        # a follows b => -1
        # a == b => 0
        # b follows a => 1
        a == b ? 0 : (a < b ? 1 : -1)
      end

      inputs_spend = []
      output_amount = send_amount + self.transaction_fee
      inputs_amount = 0

      unspent_inputs.each do |input|
        inputs_spend << input
        inputs_amount += input["amount"]
        break if inputs_amount >= output_amount
      end

      return { :error => "insufficient funds to carry out transaction" } if inputs_amount < output_amount


      outputs_hash = {}
      outputs_hash[send_address] = send_amount


      unless inputs_amount == output_amount # no change
        change = inputs_amount - output_amount
        outputs_hash[bitcoind("getrawchangeaddress", testnet)] = change
      end

      # pack then unpack
      raw_txn = bitcoind("createrawtransaction", testnet, inputs_spend, outputs_hash)

      unpacked_txn = unpack_raw_txn(raw_txn)

      # append opreturn (6a represents op_return)
      
      op_return_script = "6a" + "#{metadata.length.chr}#{metadata}".unpack("H*")[0]

      unpacked_txn["vout"].push({
        "value" => 0,
        "scriptPubKey" => op_return_script
      })

      # $raw_txn=coinspark_pack_raw_txn($txn_unpacked);
      raw_txn = pack_raw_txn(unpacked_txn)
        
      sign_txn_response = bitcoind("signrawtransaction", testnet, raw_txn)
      # txid = bitcoind("sendrawtransaction", testnet, signed_txn)

      return { :error => "error signing transaction" } unless sign_txn_response["complete"]

      txid = bitcoind("sendrawtransaction", testnet, sign_txn_response["hex"])

      if txid.length != 64
        { :error => "could not send transaction" }
      else
        { :txid => txid }
      end
    end

    private
      def bitcoind cmd, testnet, *args
        command = "#{self.bitcoind_cmd} #{testnet ? "-testnet" : ""}"

        command += " #{Shellwords.escape(cmd)}"

        args.each do |x|
          begin
            command += " #{Shellwords.escape(JSON.generate(x))}"
          rescue
            command += " #{Shellwords.escape(x)}"
          end
        end

        raw_result = `#{command}`.strip.chomp

        begin
          JSON.parse(raw_result)
        rescue
          raw_result
        end
      end

      def parse_var_int binary
        val = binary.shift!(1).unpack("C")[0]

        if val == 0xFF # 64
          unpack_uint64(binary.shift!(8))
        elsif val == 0xFE # 32 bits
          binary.shift!(4).unpack("V")[0]
        elsif val == 0xFD # 16 bits
          binary.shift!(2).unpack("v")[0]
        else
          val
        end
      end

      def pack_var_int n
        if n < 0xFD # uint8_t
          [ n ].pack("C")
        elsif n <= 0xFFFF #0xfd followed by the uint16_t
          "\xFD".b + [ n ].pack("v")
        elsif n <= 0xFFFFFFFF #0xfe followed by the uint32_t
          "\xFE".b + [ n ].pack("V")
        else #0xff followed by the length as uint64_t
          "\xFF".b + pack_uint64(n)
        end
      end

      def unpack_uint64 str
        # since it is lsb first ...
        str[0..3].unpack("V*")[0] + str[4..7].unpack("V*")[0] * (2**32)
      end

      def pack_uint64 n
        first = [ n % (2**32) ].pack("V") # small byte
        second = [ (n / (2**32)).round ].pack("V") # big byte
        first + second
      end

      def pack_raw_txn txn
        binary = "".b

        # pack version into 32 bit integer (little endian)
        #   $binary.=pack('V', $txn['version']);
        binary += [ txn["version"] ].pack("V")

        # $binary.=coinspark_pack_varint(count($txn['vin']));
        # pack varint number of input
        binary += pack_var_int(txn["vin"].length)

        # pack the inputs        
        txn["vin"].each do |input|
          binary += [ input["txid"] ].pack("H*").reverse
          binary += [ input["vout"] ].pack("V")
          # divide 2 because to positions in a hex string represents a byte
          binary += pack_var_int(input["scriptSig"].length / 2)
          binary += [ input["scriptSig"] ].pack("H*")

          binary += [ input["sequence"] ].pack("V")
          # input["sequence"].to_s(16).split("").each do |x|
          #   binary += x
          # end
        end

        # pack varint number of outputs
        binary += pack_var_int(txn["vout"].length)

        # start packing the output
        txn["vout"].each do |output|
          binary += pack_uint64((output["value"] * 100000000).round)
          binary += pack_var_int(output["scriptPubKey"].length / 2)
          binary += [ output["scriptPubKey"] ].pack("H*")
        end

        # then append the lock time
        binary += [ txn["locktime"] ].pack("V")

        # convert the real reprsentation into a hex string
        binary.unpack("H*")[0]
      end

      def unpack_raw_txn hex
        #   // see: https://en.bitcoin.it/wiki/Transactions
        
        # convert the hex representation into a real string]
        binary = [ hex ].pack("H*")
        
        txn = {}
        
        # get the version and initialize array

        txn["version"] = binary.shift!(4).unpack("V")[0]
        txn["vin"] = []
        txn["vout"] = []

        # parse the number of inputs
        n = parse_var_int(binary)
        
        # parse the inputs
        n.times do
          input = {}
          input["txid"] = binary.shift!(32).reverse.unpack("H*")[0]
          input["vout"] = binary.shift!(4).unpack("V")[0]
          script_length = parse_var_int(binary)

          input["scriptSig"] = binary.shift!(script_length).unpack("H*")[0]
          input["sequence"] = binary.shift!(4).unpack("V")[0]
          txn["vin"] << input
        end

        # parse the number of outputs
        n = parse_var_int(binary)

        # parse the outputs
        n.times do 
          output = {}
          output["value"] = binary.shift!(8).unpack("V")[0] / 100000000.0 
          # remember it is stored in satoshi inernally
          
          script_length = parse_var_int(binary)
          output["scriptPubKey"] = binary.shift!(script_length).unpack("H*")[0]
          txn["vout"] << output
        end

        # locktime
        txn["locktime"] = binary.shift!(4).unpack("V")[0]

        # error handling
        exit ("unexpected data in transaction") unless binary.length == 0

        # finally, return
        txn
      end
  end

  self.bitcoind_cmd = "/usr/local/bin/bitcoind"
  self.transaction_fee = 0.0001
end