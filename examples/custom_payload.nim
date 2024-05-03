## code to donate to my aptos address via custom contract
## the contract is available here
## NOTE :: this script automatically runs on the testnet
## NOTE :: do not run this on the mainnet if you do not intend on donating

{.define : debug.}

import std / [asyncdispatch, logging]
from std / os import getEnv
from std / strformat import fmt
import aptos

let logger = newConsoleLogger(fmtStr = "[$levelname] -> ")
addHandler(logger)

const contractAddr = ""
let 
    client = newAptosClient("https://fullnode.devnet.aptoslabs.com/v1")
    account1 = newAccount(
        getEnv("APTOS_ADDRESS1"),
        getEnv("APTOS_SEED1")
    ) 

client.close()
