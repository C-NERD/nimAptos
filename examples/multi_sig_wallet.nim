import std / [asyncdispatch]
from std / os import getEnv
import aptos

let 
    client = newAptosClient("https://fullnode.devnet.aptoslabs.com/v1")
    #faucetClient = newAptosClient("https://faucet.devnet.aptoslabs.com", true)
    account1 = client.newAccount(getEnv("APTOS_ADDRESS"), getEnv("APTOS_SEED"))
    account2 = client.newAccount(getEnv("APTOS_ADDRESS2"), getEnv("APTOS_SEED2"))

let 
    address = waitFor client.registerMultiSigAccount(account1, @[account2.address], 2)
    multiSigAccount = client.newMultiSigAccount(@[account1, account2], address, 2)

echo "address ", multiSigAccount.address
#let hashes = waitFor faucetClient.faucetFund(multiSigAccount.address, 2.toOcta())
#echo "faucet hash ", hashes
#let txnHash = waitFor client.sendAptCoin(multiSigAccount, account1.address, 0.5)
#echo "coin transfer hash ", txnHash

client.close()
