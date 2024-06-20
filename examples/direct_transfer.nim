#{.define : nodeSerialization.}

import std / [asyncdispatch, logging, json]
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
    collectionName = "cnerd's collection"

## direct transfer second token
info "performing direct transfer of token..."

let
    acctTxn = waitFor directTransferToken(account1, account2, client,
            account1.address, collectionName, "cloud and sea", 0, 0.3)
    txn = waitFor client.getTransactionByHash(acctTxn.hash)

assert getBool(getOrDefault(txn, "success")), getStr(getOrDefault(txn, "vm_status"))
notice fmt"direct transfer completed at {acctTxn.hash}"

client.close()

