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
  :metadata => "metadata"
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

the operation will return one of the two following outputs:

~~~ruby
{ :error => "error_message_occured" }
~~~

~~~ruby
{ :txid => "the_transaction_id_of_your_operation" }
~~~