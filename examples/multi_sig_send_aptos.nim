#{.define : nodeSignature.}

import std / [asyncdispatch, logging]
from std / os import getEnv
from std / strformat import fmt
import aptos

let logger = newConsoleLogger(fmtStr = "[$levelname] -> ")
addHandler(logger)

let 
    client = newAptosClient("https://fullnode.devnet.aptoslabs.com/v1")
    account1 = newAccount(
        getEnv("APTOS_ADDRESS2"),
        getEnv("APTOS_SEED2")
    )
    account2 = newAccount(
        getEnv("APTOS_ADDRESS3"),
        getEnv("APTOS_SEED3")
    )
    multiSigAccount = newMultiSigAccount(@[account1, account2], getEnv("APTOS_MULTISIG"))

let balance = waitFor multiSigAccount.accountBalanceApt(client)
if balance >= 0.2:
    
    info fmt"sending funds from {multiSigAccount.address} to {account1.address}..."
    let sendTxn = waitFor sendAptCoin(multiSigAccount, client, account1.address, 0.2)
    notice fmt"sent funds, txn at {sendTxn.hash}"

else:

    fatal fmt"wallet balance {balance} is not enough"

client.close()
