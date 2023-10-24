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

let balance = waitFor client.accountBalanceApt(account1)
if balance >= 0.5:
    
    info fmt"sending funds from {account1.address} to {account2.address}..."
    let sendTxn = waitFor client.sendAptCoin(account1, account2.address, 0.5)
    notice fmt"sent funds, txn at {sendTxn.hash}"

else:

    fatal fmt"wallet balance {balance} is not enough"

client.close()
