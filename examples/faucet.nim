{.define : debug.}

import std / [asyncdispatch, logging]
from std / os import getEnv
from std / strformat import fmt
import aptos

let logger = newConsoleLogger(fmtStr = "[$levelname] -> ")
addHandler(logger)

let 
    address1 = getEnv("APTOS_ADDRESS1")
    address2 = getEnv("APTOS_ADDRESS2")

info fmt"funding wallets {address1} and {address2} with faucet..."
let 
    faucetClient = newFaucetClient("https://faucet.devnet.aptoslabs.com")
    hash1 = waitFor faucetClient.faucetFund(address1, 1.toOcta())
    hash2 = waitFor faucetClient.faucetFund(address2, 1.toOcta())

notice fmt"txn hash for {address1} funding : {hash1}"
notice fmt"txn hash for {address2} funding : {hash2}"
faucetClient.close()

