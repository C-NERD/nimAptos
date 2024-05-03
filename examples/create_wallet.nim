#{.define : nodeSignature.}

import std / [asyncdispatch, logging]
from std / os import getEnv
from std / strformat import fmt
import aptos

let logger = newConsoleLogger(fmtStr = "[$levelname] -> ")
addHandler(logger)

info "creating new wallets..."
let 
    client = newAptosClient("https://fullnode.devnet.aptoslabs.com/v1") 
    newWallet1 = waitFor client.createWallet()
    newWallet2 = waitFor client.createWallet()

notice fmt"generated wallet {newWallet1.address} with seed {newWallet1.seed}"
notice fmt"generated wallet {newWallet2.address} with seed {newWallet2.seed}"

info "registering wallets..."
let 
    oldWallet = newAccount(getEnv("APTOS_ADDRESS1"), getEnv("APTOS_SEED1"))
    acctTxn1 = waitFor registerAccount(oldWallet, client, newWallet1)
    acctTxn2 = waitFor registerAccount(oldWallet, client, newWallet2)

notice fmt"wallets registered at {acctTxn1.hash} and {acctTxn2.hash}"
client.close()
