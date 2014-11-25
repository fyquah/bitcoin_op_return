# BitcoinOpReturn

BitcoinOpReturn is a utility to send op_return blockchain transactions into the bitcoin blockchain in ruby code.

# External Dependencies

* `bitcoind / bitcoind-qt`

# Usage

You **HAVE TO** configure the path to the bitcoind / bitcoind-qt executable. By default, it points to `/usr/local/bin/bitcoind`. This will most probably be different, depending on how you installed the bitcoin comand line utility.

~~~ruby
BitcoinOpReturn.create({
  :address => "1CT3w1LV84oCdmqD8scrru84nP6QPaR8gC", 
  :amount => 0.0001, # amount is in BTC, not satoshis
  :metadata => "metadata",
  :transaction_fee => "0.0005" # transaction_fee can be ommitted, and will default to 0.0001
})
~~~

To use it in the testnet instead of mainnet

~~~ruby
BitcoinOpReturn.create({
  :address => "1CT3w1LV84oCdmqD8scrru84nP6QPaR8gC", 
  :amount => 0.0001, # amount is in BTC, not satoshis
  :metadata => "metadata",
  :testnet => true
})
~~~

To change the path to executable bitcoind / bitcoind-qt :

~~~ruby
BitcoinOpReturn.bitcoind_cmd = "/path/to/bitcoind"
~~~

To change the default transaction fee of `0.0001` : 

~~~ruby
BitcoinOpReturn.transaction_fee = "/path/to/bitcoind"
~~~

the operation will return one of the two following outputs:

~~~ruby
{ :error => "error_message_occured" }
~~~

~~~ruby
{ :txid => "the_transaction_id_of_your_operation" }
~~~