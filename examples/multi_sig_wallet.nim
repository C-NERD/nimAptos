#{.define : nodeSignature.}

import std / [asyncdispatch, logging, json]
from std / os import getEnv
from std / strformat import fmt
import aptos

let logger = newConsoleLogger(fmtStr = "[$levelname] -> ")
addHandler(logger)

let 
    client = newAptosClient("https://fullnode.devnet.aptoslabs.com/v1")
    account1 = newAccount(getEnv("APTOS_ADDRESS1"), getEnv("APTOS_SEED1"))
    account2 = newAccount(getEnv("APTOS_ADDRESS2"), getEnv("APTOS_SEED2"))
    account3 = newAccount(getEnv("APTOS_ADDRESS3"), getEnv("APTOS_SEED3"))

info "creating multisig wallet"
let 
    acctTxn = waitFor registerMultiSigAccount(account1, client, @[account2.address, account3.address], 2)
    txn = waitFor client.getTransactionByHash(acctTxn.hash)

assert getBool(getOrDefault(txn, "success")), getStr(getOrDefault(txn, "vm_status"))

var multiSigAddress : string
for each in txn["changes"]:

    if getStr(each["type"]) == "write_resource":

        if getStr(each["data"]["type"]) == "0x1::multisig_account::MultisigAccount":

            multiSigAddress = getStr(each["address"])

let multiSigAccount = newMultiSigAccount(@[account1, account2, account3], multiSigAddress)

notice fmt"multisig account registered at {acctTxn.hash}"
notice fmt"multiSig address : {multiSigAccount.address}"
client.close()

