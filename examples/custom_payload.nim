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

## run mint function from smart contract
## NOTE :: this smart contract will be made available on the mainnet. You come participate
## in minting or any other interaction on the contract

client.close()
