import std / [asyncdispatch]
from std / os import getEnv
import aptos

let 
    client = newAptosClient("https://fullnode.devnet.aptoslabs.com/v1")
    account = newAccount(
        client, 
        getEnv("APTOS_ADDRESS"),
        getEnv("APTOS_SEED")
    )
    account2 = newAccount(
        client, 
        getEnv("APTOS_ADDRESS2"),
        getEnv("APTOS_SEED2")
    )
    collectionName = "cnerd's collection"

## direct transfer second token
echo "performing direct transfer of token"

let txn = waitFor client.directTransferToken(account, account2, account.address, collectionName, "cloud and sea", 0, 1)
echo txn.hash

