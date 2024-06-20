## This example funds accounts using the aptos faucet api

import std / [asyncdispatch, logging]
from std / os import getEnv
from std / strformat import fmt
import aptos

let logger = newConsoleLogger(fmtStr = "[$levelname] -> ")
addHandler(logger)

let
    address1 = getEnv("APTOS_ADDRESS1")
    address2 = getEnv("APTOS_ADDRESS2")
    address3 = getEnv("APTOS_ADDRESS3")
    address4 = getEnv("APTOS_ADDRESS4")
    address5 = getEnv("APTOS_MULTISIG")

info fmt"funding wallets with faucet..."
let
    faucetClient = newFaucetClient("https://faucet.devnet.aptoslabs.com")
    hash1 = waitFor faucetClient.faucetFund(address1, 1.toOcta())
    hash2 = waitFor faucetClient.faucetFund(address2, 1.toOcta())
    hash3 = waitFor faucetClient.faucetFund(address3, 1.toOcta())
    hash4 = waitFor faucetClient.faucetFund(address4, 1.toOcta())
    hash5 = waitFor faucetClient.faucetFund(address5, 1.toOcta())

notice fmt"txn hash for {address1} funding : {hash1}"
notice fmt"txn hash for {address2} funding : {hash2}"
notice fmt"txn hash for {address3} funding : {hash3}"
notice fmt"txn hash for {address4} funding : {hash4}"
notice fmt"txn hash for {address5} funding : {hash5}"

faucetClient.close()

