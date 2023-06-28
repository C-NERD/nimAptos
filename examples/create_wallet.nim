import std / [asyncdispatch]
from std / os import getEnv
import aptos

let 
    client = newAptosClient("https://fullnode.devnet.aptoslabs.com/v1")
    oldWallet = client.newAccount(getEnv("APTOS_ADDRESS"), getEnv("APTOS_SEED"))
    newWallet = client.createWallet()

let acctTxn = waitFor client.registerAccount(oldWallet, newWallet.address)
echo "txn hash ", acctTxn.hash
echo "wallet address ", newWallet.address
echo "wallet seed ", newWallet.seed

client.close()
