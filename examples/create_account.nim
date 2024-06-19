#{.define : nodeSerialization.}

import std / [asyncdispatch, logging]
from std / os import getEnv
from std / strformat import fmt
import aptos

let logger = newConsoleLogger(fmtStr = "[$levelname] -> ")
addHandler(logger)

info "creating new accounts..."
let 
    client = newAptosClient("https://fullnode.devnet.aptoslabs.com/v1") 
    newAccount1 = waitFor client.createAccount()
    newAccount2 = waitFor client.createAccount()

notice fmt"generated account {newAccount1.address} with seed {newAccount1.seed}"
notice fmt"generated account {newAccount2.address} with seed {newAccount2.seed}"

info "registering accounts..."
let 
    oldAccount = newAccount(getEnv("APTOS_ADDRESS1"), getEnv("APTOS_SEED1"))
    acctTxn1 = waitFor registerAccount(oldAccount, client, newAccount1)
    acctTxn2 = waitFor registerAccount(oldAccount, client, newAccount2)

notice fmt"accounts registered at {acctTxn1.hash} and {acctTxn2.hash}"
client.close()
