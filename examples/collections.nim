import std / [asyncdispatch, json]
from std / jsonutils import toJson
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

## create collection cnerd's collection
#echo "creating collection"
let 
    collectionName = "cnerd's collection"
    collectionTxn = waitFor client.createCollection(account, collectionName, "cnerd's aptos collection for testing nim aptos sdk", "https://c-nerd.github.io/blog/static/templates/Cnerd's Collection.html")
echo collectionTxn.hash

## create tokens for collection
echo "creating tokens"
let createTxn1 = waitFor client.createToken(account, collectionName, "tweetvibe", 
"logo for my tweet vibe project", "https://c-nerd.github.io/blog/static/images/Cnerd's_Collection/tweetvibe.png", 1, 10000)
echo createTxn1.hash

let createTxn2 = waitFor client.createToken(account, collectionName, "cloud and sea", 
"trash drawing of cloud and sea", "https://c-nerd.github.io/blog/static/images/Cnerd's_Collection/cloud_and_sea.png", 5, 10000)
echo createTxn2.hash

echo "offering 1st token"
let
    offerTxn = waitFor client.offerToken(account, account2.address, account.address, collectionName, "tweetvibe", 0, 1)
echo offerTxn.hash

## claim token offered
echo "claiming 1st token"
let
    claimTxn = waitFor client.claimToken(account2, account.address, account.address, collectionName, "tweetvibe", 0)
echo claimTxn.hash

client.close()
