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
        getEnv("APTOS_ADDRESS1"),
        getEnv("APTOS_SEED1")
    )
    account2 = newAccount(
        getEnv("APTOS_ADDRESS2"),
        getEnv("APTOS_SEED2")
    ) 

let balance = waitFor account1.accountBalanceApt(client)
if balance >= 0.2:
    
    info fmt"sending funds from {account1.address} to {account2.address}..."
    let sendTxn = waitFor sendAptCoin(account1, client, account2.address, 0.2)
    notice fmt"sent funds, txn at {sendTxn.hash}"

else:

    fatal fmt"wallet balance {balance} is not enough"

client.close()
