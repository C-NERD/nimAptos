## This example sends apt with multiSig Account but using normal account Resources
#{.define : nodeSerialization.}

import std / [asyncdispatch, logging]
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
    multiSigAcct = newMultiSigAccount(@[account1, account2, account3, account4],
            getEnv("APTOS_MULTISIG"))

info "funding multiSig account ..."
let faucetTxn = waitFor faucetClient.faucetFund($multiSigAcct.address, 1.toOcta())
notice fmt"multiSigAcct funded at {faucetTxn[0]}"

let balance = waitFor multiSigAcct.accountBalanceApt(client)
if balance >= 0.2:

    info fmt"sending funds from {multiSigAcct.address} to {account1.address}..."
    let
        sendTxn = waitFor sendAptCoin(multiSigAcct, client, account1.address, 0.2)
        sendTxn2 = waitFor client.getTransactionByHash(sendTxn.hash)

    #assert getBool(sendTxn2["success"]), getStr(sendTxn2["vm_status"])
    notice fmt"sent funds, txn at {sendTxn.hash}"

else:

    fatal fmt"wallet balance {balance} is not enough"

client.close()
