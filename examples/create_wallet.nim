{.define : debug.}

import std / [asyncdispatch, logging]
from std / os import getEnv
from std / strformat import fmt
import aptos

let logger = newConsoleLogger(fmtStr = "[$levelname] -> ")
addHandler(logger)

#info "creating new wallets..."
let 
    client = newAptosClient("https://fullnode.devnet.aptoslabs.com/v1") 
    newWallet1 = waitFor client.createWallet()
    newWallet2 = waitFor client.createWallet()

notice fmt"generated wallet {newWallet1.address} with seed {newWallet1.seed}"
notice fmt"generated wallet {newWallet2.address} with seed {newWallet2.seed}"

#[info "registering wallets..."
let 
    oldWallet = newAccount(getEnv("APTOS_ADDRESS1"), getEnv("APTOS_SEED1"))
    acctTxn = waitFor client.registerAccount(oldWallet, newWallet1.address)
    acctTxn = waitFor client.registerAccount(oldWallet, newWallet2.address)

notice fmt"registered wallets {newWallet1.address} and {newWallet2.address}"]#
client.close()
