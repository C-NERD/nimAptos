import std / [asyncdispatch]
from std / os import getEnv
import aptos

let 
    client = newAptosClient("https://fullnode.devnet.aptoslabs.com/v1")
    faucetClient = newAptosClient("https://faucet.devnet.aptoslabs.com", true)
    account1 = newAccount(
        client, 
        getEnv("APTOS_ADDRESS"),
        getEnv("APTOS_SEED")
    )
    account2 = newAccount(
        client, 
        getEnv("APTOS_ADDRESS2"),
        getEnv("APTOS_SEED2")
    )
    multiSigAccount = newMultiSigAccount(
        client,
        @[account1, account2],
        getEnv("APTOS_MULTI_SIG_ADDRESS"),
        2
    )


echo "funding wallet from faucet"
let fundingHashes = waitFor faucetClient.faucetFund(multiSigAccount.address, 1.toOcta()) ## get 5 aptos funded to your wallet
echo fundingHashes

client.close()

