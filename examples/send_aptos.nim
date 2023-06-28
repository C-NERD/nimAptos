import std / [asyncdispatch]
from std / os import getEnv
import aptos

let 
    client = newAptosClient("https://fullnode.devnet.aptoslabs.com/v1")
    account1 = newAccount(
        client, 
        getEnv("APTOS_ADDRESS"),
        getEnv("APTOS_SEED")
    )
    account2 = newAccount(
        client, 
        getEnv("APTOS_ADDRESS2"),
        getEnv("APTOS_SEED2")
    )
    multiSigAccount = newMultiSigAccount(
        client,
        @[account1, account2],
        getEnv("APTOS_MULTI_SIG_ADDRESS")
    )

#[let balance = waitFor client.accountBalanceApt(account1)
if balance >= 0.5:
    
    echo "sending funds to recipient"
    let sendTxn = waitFor client.sendAptCoin(account1, account2.address, 0.5)
    echo sendTxn.hash ## echo transaction]#

if waitFor(client.accountBalanceApt(multiSigAccount)) > 0.2:

    echo "sending funds to recipient"
    let sendTxn = waitFor client.sendAptCoin(multiSigAccount, account2.address, 0.2)
    echo sendTxn.hash

client.close()
