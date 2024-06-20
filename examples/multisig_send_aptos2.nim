## This example sends aptos using multiSig Account Resource
## NOTE :: after voting, the move vm is meant to execute the multisig payload
## but I haven't been have to get it to do that from my tests
#{.define : nodeSerialization.}

import std / [asyncdispatch, logging]
from std / os import getEnv
from std / strformat import fmt
import aptos

let logger = newConsoleLogger(fmtStr = "[$levelname] -> ")
addHandler(logger)

let 
    client = newAptosClient("https://fullnode.devnet.aptoslabs.com/v1")
    faucetClient = newFaucetClient("https://faucet.devnet.aptoslabs.com") 
    account1 = newAccount(
        getEnv("APTOS_ADDRESS1"),
        getEnv("APTOS_SEED1")
    )
    account2 = newAccount(
        getEnv("APTOS_ADDRESS2"),
        getEnv("APTOS_SEED2")
    )
    account3 = newAccount(
        getEnv("APTOS_ADDRESS3"),
        getEnv("APTOS_SEED3")
    )
    account4 = newNonPrivilegedAccount(
        getEnv("APTOS_ADDRESS4")
    ) ## seed not known

var multiSigAcct = newMultiSigAccount(@[account1, account2, account3, account4], getEnv("APTOS_MULTISIG"))

#[info "funding multiSig account ..."
let faucetTxn = waitFor faucetClient.faucetFund($multiSigAcct.address, 1.toOcta())
notice fmt"multiSigAcct funded at {faucetTxn[0]}"]#

let balance = waitFor multiSigAcct.accountBalanceApt(client)
if balance >= 0.2:
    
    info fmt"initiating txn to send funds from {multiSigAcct.address} to {account1.address}..."
    let sendTxn = waitFor multiSigSendAptCoin(account1, multiSigAcct, client, account1.address, 0.2)
    notice fmt"txn created at {sendTxn.hash}"

    info fmt"{account1.address} and {account2.address} are voting to approve txn"
    waitFor refresh(multiSigAcct, client)
    let
        sendTxn2 = waitFor multiSigTxnVote(account1, multiSigAcct, client, multiSigAcct.next_sequence_number - 1, Vote.Approve)
        sendTxn3 = waitFor multiSigTxnVote(account2, multiSigAcct, client, multiSigAcct.next_sequence_number - 1, Vote.Approve)
        sendTxn4 = waitFor multiSigTxnVote(account3, multiSigAcct, client, multiSigAcct.next_sequence_number - 1, Vote.Approve)

    #assert getBool(sendTxn2["success"]), getStr(sendTxn2["vm_status"])
    notice fmt"first vote at {sendTxn2.hash}"
    notice fmt"second vote at {sendTxn3.hash}"
    notice fmt"third vote at {sendTxn4.hash}"

else:

    fatal fmt"wallet balance {balance} is not enough"

client.close()
