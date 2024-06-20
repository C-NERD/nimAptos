#{.define : nodeSerialization.}

import std / [asyncdispatch, logging, json]
from std / os import getEnv, sleep
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
    singleSigAcct = waitFor createAccount(client)

info "funding account1 ..."
let faucetTxn1 = waitFor faucetClient.faucetFund($account1.address, 1.toOcta())
notice fmt"account1 funded at {faucetTxn1[0]}"

info "registering account on chain ..."
let txn1 = waitFor account1.registerAccount(client, singleSigAcct)
notice fmt"account registered at {txn1.hash}"

var registerTxn = waitFor client.getTransactionByHash(txn1.hash)
while getStr(registerTxn["type"]) == "pending_transaction": ## poll until transaction is completed

    registerTxn = waitFor client.getTransactionByHash(txn1.hash)
    sleep(500) ## 500ms delay on polls

assert getBool(registerTxn["success"]), getStr(registerTxn["vm_status"])
info fmt"account {singleSigAcct.address} registered successfully"

info "registering multiSig account on chain ..."
let txn2 = waitFor account1.registerMultiSigAcctFromExistingAcct(
    client, 
    singleSigAcct, 
    @[account1, account2, account3, account4],
    2
)
notice fmt"multiSig account registered at {txn2.hash}"

registerTxn = waitFor client.getTransactionByHash(txn2.hash)
while getStr(registerTxn["type"]) == "pending_transaction": ## poll until transaction is completed

    registerTxn = waitFor client.getTransactionByHash(txn2.hash)
    sleep(500)

assert getBool(registerTxn["success"]), getStr(registerTxn["vm_status"])
info fmt"multiSig account {singleSigAcct.address} registered successfully"

info "funding multi sig account ..."
let faucetTxn2 = waitFor faucetClient.faucetFund($singleSigAcct.address, 1.toOcta())
notice fmt"multi sig account funded at {faucetTxn2[0]}"

info "performing rotation proof challenge on new multi sig account ..."
let 
    multiSigAcct = newMultiSigAccount(
        @[account1, account2, account3, account4],
        $singleSigAcct.address
    )

let
    txn3 = waitFor rotationProofChallenge(
        singleSigAcct,
        multiSigAcct,
        client
    )
notice fmt"rotation proof challenge performed at {txn3.hash}"

registerTxn = waitFor client.getTransactionByHash(txn3.hash)
while getStr(registerTxn["type"]) == "pending_transaction": ## poll until transaction is completed

    registerTxn = waitFor client.getTransactionByHash(txn3.hash)
    sleep(500)

assert getBool(registerTxn["success"]), getStr(registerTxn["vm_status"])
info fmt"rotation proof challenge rotated public key from {singleSigAcct.getPublicKey()} to {multiSigAcct.getPublicKey()}"

