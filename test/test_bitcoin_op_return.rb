# encoding: UTF-8
require "minitest/autorun"
require "./lib/bitcoin-op-return.rb"

class BitcoinOpReturnTest < Minitest::Test
  SAMPLE_RAW_TXN = ["0100000001c4b6a6a63db978d9d7126091aa09d45d2c50a913b083c61cbe5cf3186164c95b0000000000ffffffff0310270000000000001976a9142f19e72489d51a1903c20bf8a371f5a823abfb8588aca0782d00000000001976a914297eea0230017cc4f5e0c7d54a8484ce84f001ae88ac00000000000000000a6a086d6574616461746100000000", "0100000001c4b6a6a63db978d9d7126091aa09d45d2c50a913b083c61cbe5cf3186164c95b0000000000ffffffff0330750000000000001976a9147d96a539f86fc1c706fce932b57a3b873d06847a88ac802a2d00000000001976a91427679fbf906e43f7e72c79c43b7c3a20770a79c288ac00000000000000000a6a086d6574616461746100000000"
  ]
  SAMPLE_UNPACKED_TXN = [{
    "version" => 1,
    "vin" => [
      {
        "txid" => "5bc9646118f35cbe1cc683b013a9502c5dd409aa916012d7d978b93da6a6b6c4",
        "vout" => 0,
        "scriptSig" => "",
        "sequence" => 0xFFFFFFFF
      }
    ],
    "vout" => [
      {
        "value" => 0.0001,
        "scriptPubKey" => "76a9142f19e72489d51a1903c20bf8a371f5a823abfb8588ac"
      },
      {
        "value" => 0.02980000,
        "scriptPubKey" => "76a914297eea0230017cc4f5e0c7d54a8484ce84f001ae88ac"
      },
      {
        "value" => 0,
        "scriptPubKey" => "6a086d65746164617461"
      }
    ],
    "locktime" => 0
  }, {
    "version" => 1,
    "vin" => [
      {
        "txid" => "5bc9646118f35cbe1cc683b013a9502c5dd409aa916012d7d978b93da6a6b6c4",
        "vout" => 0,
        "scriptSig" => "",
        "sequence" => 0xffffffff
      }
    ],
    "vout" => [
      {
        "value" => 0.0003,
        "scriptPubKey" => "76a9147d96a539f86fc1c706fce932b57a3b873d06847a88ac"
      },
      {
        "value" => 0.0296,
        "scriptPubKey" => "76a91427679fbf906e43f7e72c79c43b7c3a20770a79c288ac"
      },
      {
        "value" => 0,
        "scriptPubKey" => "6a086d65746164617461"
      }
    ],
    "locktime" => 0
  }]
  def test_validate_address
    msg = BitcoinOpReturn.create({
      "send_amount" => 1,
      "send_address" => 1,
      "metadata" => "hello world"
    })
    assert_equal msg, { "error" => "invalid address" }
  end

  def test_pack_uint64
    n = 0xFFFFFFFFAAAAAAAA
    lsb = [ 0xAAAAAAAA ].pack("V")
    msb = [ 0xFFFFFFFF ].pack("V")
    assert_equal BitcoinOpReturn.send(:pack_uint64, n), lsb + msb
    # remember msb first in little endian
  end 

  def test_unpack_uint64
    n = 0xFFFFFFFFAAAAAAAA
    lsb = [ 0xAAAAAAAA ].pack("V")
    msb = [ 0xFFFFFFFF ].pack("V")
    hex = "#{lsb}#{msb}"
    assert_equal BitcoinOpReturn.send(:unpack_uint64, hex), n
  end

  def test_parse_var_int
    # Value Storage length  Format
    # < 0xfd  1 uint8_t
    x = [ 0xfa ].pack("C")
    assert_equal BitcoinOpReturn.send(:parse_var_int, x), 0xFA

    # <= 0xffff 3 0xfd followed by the length as uint16_t
    x = "\xFD".b + [ 0xffff ].pack("v")
    assert_equal BitcoinOpReturn.send(:parse_var_int, x), 0xFFFF

    # <= 0xffffffff 5 0xfe followed by the length as uint32_t
    x = "\xFE".b + [ 0xffffffff ].pack("V")
    assert_equal BitcoinOpReturn.send(:parse_var_int, x), 0xffffffff

    # - 9 0xff followed by the length as uint64_t
    x = "\xFF".b + BitcoinOpReturn.send(:pack_uint64, 0xFFFFFFFFFFFFFFFF)    
    assert_equal BitcoinOpReturn.send(:parse_var_int, x), 0xFFFFFFFFFFFFFFFF
  end

  def test_pack_var_int
    # Value Storage length  Format
    # < 0xfd  uint8_t
    assert_equal BitcoinOpReturn.send(:pack_var_int, 0xfa), [ 0xfa ].pack("C")

    # <= 0xffff 0xfd followed by the length as uint16_t
    assert_equal BitcoinOpReturn.send(:pack_var_int, 0xfffe), "\xfd".b + [ 0xfffe ].pack("v")

    # <= 0xffffffff 0xfe followed by the length as uint32_t
    assert_equal BitcoinOpReturn.send(:pack_var_int, 0xffffffff), "\xfe".b + [ 0xffffffff ].pack("V")
    
    # - 0xff followed by the length as uint64_t
    n = 0xffffffffaaaaaaa
    packed_uint64 = "#{[ n % (2**32) ].pack "V"}#{[ (n / (2**32)).round ].pack "V"}"
    assert_equal BitcoinOpReturn.send(:pack_var_int, n), "\xff".b + packed_uint64
  end

  def test_pack_raw_txn
    SAMPLE_UNPACKED_TXN.each_with_index do |json, i|
      assert_equal SAMPLE_RAW_TXN[i], BitcoinOpReturn.send(:pack_raw_txn, json)
    end
  end

  def test_unpack_raw_txn
    SAMPLE_RAW_TXN.each_with_index do |txn, i|
      assert_equal SAMPLE_UNPACKED_TXN[i], BitcoinOpReturn.send(:unpack_raw_txn, txn)
    end
  end
  
end