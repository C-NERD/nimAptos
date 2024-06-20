#{.define : nodeSerialization.}

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
    collectionTxn = waitFor account1.createCollection(client, collectionName,
            "cnerd's aptos collection for testing nim aptos sdk",
            "https://c-nerd.github.io/blog/static/templates/Cnerd's Collection.html",
            high(uint64), [true, false, false]
    )
notice fmt"collection created at {collectionTxn.hash}"

## create tokens for collection
info "creating tokens..."
let createTxn1 = waitFor account1.createToken(client, collectionName,
        "tweetvibe",
"logo for my tweet vibe project", "https://c-nerd.github.io/blog/static/images/Cnerd's_Collection/tweetvibe.png",
        1, 1, 10000, 1000, [false, false, false, true, false])
notice fmt"token 1 created at {createTxn1.hash}"

let createTxn2 = waitFor account1.createToken(client, collectionName,
        "cloud and sea",
"trash drawing of cloud and sea", "https://c-nerd.github.io/blog/static/images/Cnerd's_Collection/cloud_and_sea.png",
        1, 1, 10000, 1000, [false, false, false, true, false])
notice fmt"token 2 created at {createTxn2.hash}"

## offering tokens
info "offering token 1..."
let offerTxn = waitFor account1.offerToken(client, account2.address,
        account1.address, collectionName, "tweetvibe", 0, 1)
## offer token for 0.5 apt
notice fmt"token 1 offered at {offerTxn.hash}"

## claim token offered
info "claiming token 1..."
let claimTxn = waitFor account2.claimToken(client, account1.address,
        account1.address, collectionName, "tweetvibe", 0)
notice fmt"token 1 claimed at {claimTxn.hash}"

client.close()

