#{.define : nodeSerialization.}

import std / [asyncdispatch, logging, json]
from std / os import getEnv
from std / strformat import fmt
import aptos

let logger = newConsoleLogger(fmtStr = "[$levelname] -> ")
addHandler(logger)

let
    client = newAptosClient("https://fullnode.devnet.aptoslabs.com/v1")
    faucetClient = newFaucetClient("https://faucet.devnet.aptoslabs.com")
    account1 = newAccount(
        getEnv("APTOS_ADDRESS1"),
        getEnv("APTOS_SEED1")
    )
    account2 = newAccount(
        getEnv("APTOS_ADDRESS2"),
        getEnv("APTOS_SEED2")
    )
    account3 = newAccount(
        getEnv("APTOS_ADDRESS3"),
        getEnv("APTOS_SEED3")
    )
    account4 = newAccount(
        getEnv("APTOS_ADDRESS4"),
        getEnv("APTOS_SEED4")
    )
    multiSigAcct = waitFor createMultiSigAccount(client, @[account1, account2,
            account3, account4], 2)

info "funding account1 ..."
let faucetTxn1 = waitFor faucetClient.faucetFund($account1.address, 1.toOcta())
notice fmt"account1 funded at {faucetTxn1[0]}"

info "registering account on chain ..."
let txn1 = waitFor account1.registerAccount(client, multiSigAcct)
notice fmt"account registered at {txn1.hash}"

info "registering multiSig account on chain ..."
let txn2 = waitFor account1.registerMultiSigAcctFromExistingAcct(
    client,
    multiSigAcct,
    @[account1, account2, account3, account4],
    2
)
notice fmt"multiSig account registered at {txn2.hash}"

var registerTxn = waitFor client.getTransactionByHash(txn2.hash)
while getStr(registerTxn["type"]) == "pending_transaction": ## poll until transaction is completed

    registerTxn = waitFor client.getTransactionByHash(txn2.hash)

assert getBool(registerTxn["success"]), getStr(registerTxn["vm_status"])
info fmt"multiSig account {multiSigAcct.address} registered successfully"
