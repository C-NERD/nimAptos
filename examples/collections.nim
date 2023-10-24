{.define : debug.}

import std / [asyncdispatch, logging]
from std / os import getEnv
from std / strformat import fmt
import aptos

let logger = newConsoleLogger(fmtStr = "[$levelname] -> ")
addHandler(logger)

let 
    client = newAptosClient("https://fullnode.devnet.aptoslabs.com/v1")
    account1 = newAccount(
        getEnv("APTOS_ADDRESS1"),
        getEnv("APTOS_SEED1")
    )
    account2 = newAccount( 
        getEnv("APTOS_ADDRESS2"),
        getEnv("APTOS_SEED2")
    )

## create collection cnerd's collection
info "creating new collection..."
let 
    collectionName = "cnerd's collection"
    collectionTxn = waitFor client.createCollection(account1, collectionName, "cnerd's aptos collection for testing nim aptos sdk", "https://c-nerd.github.io/blog/static/templates/Cnerd's Collection.html")
notice fmt"collection created at {collectionTxn.hash}"

## create tokens for collection
info "creating tokens..."
let createTxn1 = waitFor client.createToken(account1, collectionName, "tweetvibe", 
"logo for my tweet vibe project", "https://c-nerd.github.io/blog/static/images/Cnerd's_Collection/tweetvibe.png", 1, 10000)
notice fmt"token 1 created at {createTxn1.hash}"

let createTxn2 = waitFor client.createToken(account1, collectionName, "cloud and sea", 
"trash drawing of cloud and sea", "https://c-nerd.github.io/blog/static/images/Cnerd's_Collection/cloud_and_sea.png", 5, 10000)
notice fmt"token 2 created at {createTxn2.hash}"

## offering tokens
info "offering token 1..."
let
    offerTxn = waitFor client.offerToken(account1, account2.address, account1.address, collectionName, "tweetvibe", 0, 1)
notice fmt"token 1 offered at {offerTxn.hash}"

## claim token offered
info "claiming token 1..."
let
    claimTxn = waitFor client.claimToken(account2, account1.address, account1.address, collectionName, "tweetvibe", 0)
notice fmt"token 1 claimed at {claimTxn.hash}"

client.close()
