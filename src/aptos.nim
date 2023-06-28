#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## This module implements sugars to work with the aptos node api and other modules.
## if you want more in depth control, use the nodehttp module, account module, 
## datatype module and utils module

## NOTE :: pass the -d:nodeSignature option while compiling to encode all transactions
## directly on the aptos node
## If this option is not passed all transactions will be encoded locally

## std imports
import std / [asyncdispatch, json]
from std / strutils import parseInt
from std / strformat import fmt

## project imports
import aptos / [datatype, account, utils, api/nodehttp]

## project exports
export datatype, account, utils, nodehttp

##
var DEFAULT_MAX_GAS_AMOUNT* = 10000 ## change this to what you want the default max gas
## amount to be

## extension procs to node api
template sign(sync : bool = false, encodedTxn : string = "") =
    ## encodes and signs transaction as single ed25519 transaction
    ## params sync :: should nodeSignature be syncronous (true) or asyncronous (false)
    ## requires ::
    ## variable account : RefAptosAccount
    ## variable client : RefAptosClient (only required when `nodeSignature` is defined)
    ## variable transaction : RawTransaction
    ## to be defined
    when defined(nodeSignature):

        ## encode transaction on the node
        when not sync:

            signedTransaction = await signTransaction(account, client, transaction, encodedTxn)

        else:

            signedTransaction = waitFor signTransaction(account, client, transaction, encodedTxn)

    else:
        
        #signedTransaction = signTransaction(account, transaction)
        {.fatal : "local bcs signing for aptos account not yet implemnted".}

template multiSign(sync : bool = false, encodedTxn : string = "") =
    ## encodes and signs transaction as multi ed25519 transaction
    ## params sync :: should nodeSignature be syncronous (true) or asyncronous (false)
    ## requires ::
    ## variable account : RefMultiSigAccount
    ## variable client : RefAptosClient (only required when `nodeSignature` is defined)
    ## variable transaction : RawTransaction
    ## to be defined
    when defined(nodeSignature):

        ## encode transaction on the node
        when not sync:

            signedTransaction = await multiSignTransaction(multiSigAccount, client, transaction, encodedTxn)

        else:

            signedTransaction = waitFor multiSignTransaction(multiSigAccount, client, transaction, encodedTxn)

    else:
        
        {.fatal : "local bcs signing for multisig account not yet implemented".}

template validateGasFees() {.dirty.} =
    ## gas_price is in octa

    var
        max_gas_amount = max_gas_amount
        gas_price = gas_price

    if max_gas_amount < 0:

        max_gas_amount = DEFAULT_MAX_GAS_AMOUNT

    if gas_price < 0:

        let gasInfo = await client.estimateGasPrice()
        gas_price = gasInfo.prioritized_gas_estimate

proc accountBalanceApt*[T : RefAptosAccount | RefMultiSigAccount](client : RefAptosClient, 
    account : T) : Future[float] {.async.} =

    let resource = await client.getAccountResource(account.address, AptCoinResourceType)
    return parseInt(resource.coin_data.coin.value).toApt()

proc sendAptCoin*[T : RefAptosAccount | RefMultiSigAccount](client : RefAptosClient, account : T, recipient : string, 
    amount : float, max_gas_amount, gas_price, txn_duration : int64 = -1) : Future[SubmittedTransaction] {.async.} =
    ## param amount: amount to send in aptos
    ## txn_duration : amount of time in seconds till transaction timeout
    ## if < 0 then the library will handle it
    ## returns transaction
    
    if not isValidSeed(recipient):

        raise newException(InvalidSeed, fmt"recipient's address {recipient} is invalid")

    validateGasFees()

    var transaction = client.buildTransaction(account, max_gas_amount, gas_price, txn_duration)
    transaction.payload = Payload(
        `type` : EntryFunction,
        function : "0x1::coin::transfer",
        entry_type_arguments : @["0x1::aptos_coin::AptosCoin"],
        entry_arguments : @[newJString(recipient), newJString($(amount.toOcta()))]
    )

    var signedTransaction : SignTransaction
    when T is RefAptosAccount:

        sign()

    elif T is RefMultiSigAccount:

        let multiSigAccount = account
        multiSign()

    let submittedTransaction = await client.submitTransaction(signedTransaction)
    account.incrementSeqNum()
    return submittedTransaction

proc createCollection*[T : RefAptosAccount | RefMultiSigAccount](client : RefAptosClient, account : T, name, 
    description, uri : string, max_gas_amount, gas_price, txn_duration : int64 = -1) : Future[SubmittedTransaction] {.async.} =
    ## returns transaction

    validateGasFees() 

    var 
        transaction = client.buildTransaction(account, max_gas_amount, gas_price, txn_duration)
        lastArg = newJArray()

    for _ in 1..3:

        lastArg.add newJBool(false)
    
    transaction.payload = Payload(
        `type` : EntryFunction,
        function : "0x3::token::create_collection_script",
        entry_type_arguments : @[],
        entry_arguments : @[
            newJString(name), newJString(description), newJString(uri), newJString($high(uint64)),
            lastArg
        ]
    )
    
    var signedTransaction : SignTransaction
    when T is RefAptosAccount:

        sign()

    elif T is RefMultiSigAccount:

        let multiSigAccount = account
        multiSign()

    let submittedTransaction = await client.submitTransaction(signedTransaction)
    account.incrementSeqNum()
    return submittedTransaction

proc createToken*[T : RefAptosAccount | RefMultiSigAccount](client : RefAptosClient, account : T, collection, name, 
    description, uri : string, supply, royalty_pts_per_million : uint64, max_gas_amount, gas_price,
    txn_duration : int64 = -1) : Future[SubmittedTransaction] {.async.} =
    ## returns transaction
    
    validateGasFees()

    var 
        transaction = client.buildTransaction(account, max_gas_amount, gas_price, txn_duration)
        boolArray = newJArray()

    for _ in 1..5:

        boolArray.add newJBool(false)
    
    transaction.payload = Payload(
        `type` : EntryFunction,
        function : "0x3::token::create_token_script",
        entry_type_arguments : @[],
        entry_arguments : @[
            newJString(collection), newJString(name), newJString(description),
            newJString($supply), newJString($supply), newJString(uri), newJString(account.address),
            newJString($1000000), newJString($royalty_pts_per_million), boolArray,
            newJArray(), newJArray(), newJArray()
        ]
    )

    var signedTransaction : SignTransaction
    when T is RefAptosAccount:

        sign()

    elif T is RefMultiSigAccount:

        let multiSigAccount = account
        multiSign()

    let submittedTransaction = await client.submitTransaction(signedTransaction)
    account.incrementSeqNum()
    return submittedTransaction

proc offerToken*[T : RefAptosAccount | RefMultiSigAccount](client : RefAptosClient, account : T, recipient, creator, 
    collection, token : string, property_version, amount : uint64, max_gas_amount, gas_price,
    txn_duration : int64 = -1) : Future[SubmittedTransaction] {.async.} =
    ## returns transaction
    
    if not isValidSeed(recipient):

        raise newException(InvalidSeed, fmt"recipient's address {recipient} is invalid")

    if not isValidSeed(creator):

        raise newException(InvalidSeed, fmt"creator's address {creator} is invalid")

    validateGasFees()

    var transaction = client.buildTransaction(account, max_gas_amount, gas_price, txn_duration)
    transaction.payload = Payload(
        `type` : EntryFunction,
        function : "0x3::token_transfers::offer_script",
        entry_type_arguments : @[],
        entry_arguments : @[
            newJString(recipient), newJString(creator), newJString(collection),
            newJString(token), newJString($property_version), newJString($amount)
        ]
    )

    var signedTransaction : SignTransaction
    when T is RefAptosAccount:

        sign()

    elif T is RefMultiSigAccount:

        let multiSigAccount = account
        multiSign()

    let submittedTransaction = await client.submitTransaction(signedTransaction)
    account.incrementSeqNum()
    return submittedTransaction

proc claimToken*[T : RefAptosAccount | RefMultiSigAccount](client : RefAptosClient, account : T, sender, 
    creator, collection, token : string, property_version : uint64, max_gas_amount, gas_price,
    txn_duration : int64 = -1) : Future[SubmittedTransaction] {.async.} =
    ## returns transaction
    
    if not isValidSeed(sender):

        raise newException(InvalidSeed, fmt"sender's address {sender} is invalid")

    if not isValidSeed(creator):

        raise newException(InvalidSeed, fmt"creator's address {creator} is invalid")

    validateGasFees()

    var transaction = client.buildTransaction(account, max_gas_amount, gas_price, txn_duration)
    transaction.payload = Payload(
        `type` : EntryFunction,
        function : "0x3::token_transfers::claim_script",
        entry_type_arguments : @[],
        entry_arguments : @[
            newJString(sender), newJString(creator), newJString(collection),
            newJString(token), newJString($property_version)
        ]
    )

    var signedTransaction : SignTransaction
    when T is RefAptosAccount:

        sign()

    elif T is RefMultiSigAccount:

        let multiSigAccount = account
        multiSign()

    let submittedTransaction = await client.submitTransaction(signedTransaction)
    account.incrementSeqNum()
    return submittedTransaction

proc directTransferToken*[T, K : RefAptosAccount | RefMultiSigAccount](client : RefAptosClient, sender : T, recipient : K, 
    creator, collection, token : string, property_version, amount : uint64, max_gas_amount, gas_price,
    txn_duration : int64 = -1) : Future[SubmittedTransaction] {.async.} =

    if not isValidSeed(creator):

        raise newException(InvalidSeed, fmt"creator's address {creator} is invalid")

    validateGasFees()

    var transaction = client.buildTransaction(sender, max_gas_amount, gas_price, txn_duration)
    transaction.payload = Payload(
        `type` : EntryFunction,
        function : "0x3::token::direct_transfer_script",
        entry_type_arguments : @[],
        entry_arguments : @[
            newJString(creator), newJString(collection),
            newJString(token), newJString($property_version), newJString($amount)
        ]
    )    
    var multiAgentTransaction = toMultiAgentRawTransaction(transaction)
    multiAgentTransaction.secondary_signers = @[recipient.address]

    let encodedTransaction = await client.encodeSubmission(multiAgentTransaction)
    var 
        signedTransaction : SignTransaction
        account : RefAptosAccount
        multiSigAccount : RefMultiSigAccount
    when T is RefAptosAccount:

        account = sender
        sign(false, encodedTransaction)

    elif T is RefMultiSigAccount:

        multiSigAccount = sender
        multiSign(false, encodedTransaction)

    let senderSig = signedTransaction.signature
    when K is RefAptosAccount:

        account = recipient
        sign(false, encodedTransaction)

    elif T is RefMultiSigAccount:

        multiSigAccount = recipient
        multiSign(false, encodedTransaction)

    signedTransaction = multiAgentSignTransaction(
        senderSig, 
        @[signedTransaction.signature],
        @[recipient.address],
        transaction
    )

    let submittedTransaction = await client.submitTransaction(signedTransaction)
    sender.incrementSeqNum()
    recipient.incrementSeqNum()
    return submittedTransaction

proc registerAccount*[T : RefAptosAccount | RefMultiSigAccount](client : RefAptosClient, account : T, address : string, 
    max_gas_amount, gas_price, txn_duration : int64 = -1) : Future[SubmittedTransaction] {.async.} =
    ## register address for new wallet account
    ## returns transaction

    if not isValidSeed(address):

        raise newException(InvalidSeed, fmt"address {address} is invalid")
    
    validateGasFees()

    let transaction = client.buildTransaction(account, max_gas_amount, gas_price, txn_duration)
    transaction.payload = Payload(
        `type` : EntryFunction,
        function : "0x1::aptos_account::create_account",
        entry_type_arguments : @[],
        entry_arguments : @[newJString(address)]
    )

    var signedTransaction : SignTransaction
    when T is RefAptosAccount:
        
        sign()

    elif T is RefMultiSigAccount:

        let multiSigAccount = account
        multiSign()
    
    let submittedTransaction = await client.submitTransaction(signedTransaction)
    account.incrementSeqNum()
    return submittedTransaction

proc registerMultiSigAccount*[T : RefAptosAccount | RefMultiSigAccount](client : RefAptosClient, account : T, owners : seq[string], threshold : int,
    max_gas_amount, gas_price, txn_duration : int64 = -1) : Future[string] {.async.} =
    ## creates new multisig account with account as signer
    ## and owners as additional owners.
    ## make sure that account address is not repeated in owners param
    ## returns account address of new multisig account
    
    var ownersArg = newJArray()
    for owner in owners:

        if not isValidSeed(owner):

            raise newException(InvalidSeed, fmt"address {owner} is invalid")

        ownersArg.add newJString(owner)
    
    validateGasFees()

    let transaction = client.buildTransaction(account, max_gas_amount, gas_price, txn_duration)
    transaction.payload = Payload(
        `type` : EntryFunction,
        function : "0x1::multisig_account::create_with_owners",
        entry_type_arguments : @[],
        entry_arguments : @[ownersArg, newJString($threshold), newJArray(), newJArray()]
    )

    var signedTransaction : SignTransaction
    when T is RefAptosAccount:
        
        sign()

    elif T is RefMultiSigAccount:

        let multiSigAccount = account
        multiSign()
    
    let submittedTransaction = await client.submitTransaction(signedTransaction)
    account.incrementSeqNum()

    var userTransaction : Transaction
    while true:
        ## keep trying to get transaction info
        
        try:

            userTransaction = await client.getTransactionByHash(submittedTransaction.hash)
            break

        except ApiError:

            continue

    if userTransaction.`type` != UserTransaction:

        raise newException(InvalidTransaction, "Transaction is not of type UserTransaction")

    return userTransaction.user_events[0].guid.account_address

proc publishPackage*[T : RefAptosAccount | RefMultiSigAccount](client : RefAptosClient, account : T, 
    package_meta : openArray[byte], modules : seq[openArray[byte]]) : Future[string] {.async.} =

    discard

template customTransaction*[T : RefAptosAccount | RefMultiSigAccount](client : RefAptosClient, account : T, before, 
    after, lastly : untyped) =
    ## template for  running custom transactions
    ## param before :: code to run before transaction signing. This code has access to the variable beforeVals.
    ## This variable is of value (max_gas_amount : default, gas_price : from node, txn_duration : -1, payload : entryfun)
    ## param after :: code to run after transaction signing. This code has access to the variable signedTransaction.
    ## This variable is of type SignTransaction
    ## param lastly :: code to run after transaction has been submitted. This code has access to variable 
    ## submittedTransaction of type SubmittedTransaction.
    
    var beforeVals {.inject.} = (
        max_gas_amount : DEFAULT_MAX_GAS_AMOUNT, 
        gas_price : (waitFor client.estimateGasPrice()).prioritized_gas_estimate, 
        txn_duration : -1,
        payload : Payload(`type` : EntryFunction)
    )

    before

    let transaction {.inject.} = client.buildTransaction(
        account,
        beforeVals.max_gas_amount, 
        beforeVals.gas_price, 
        beforeVals.txn_duration
    )
    transaction.payload = beforeVals.payload

    var signedTransaction {.inject.} : SignTransaction
    when T is RefAptosAccount:
        
        sign(true)

    elif T is RefMultiSigAccount:

        let multiSigAccount = account
        multiSign(true)

    after
    
    let submittedTransaction {.inject.} = waitFor client.submitTransaction(signedTransaction)
    account.incrementSeqNum()

    lastly

template asyncCustomTransaction*[T : RefAptosAccount | RefMultiSigAccount](client : RefAptosClient, account : T, before, 
    after, lastly : untyped) =
    ## template for  running custom transactions
    ## param before :: code to run before transaction signing. This code has access to the variable beforeVals.
    ## This variable is of value (max_gas_amount : default, gas_price : from node, txn_duration : -1, payload : entryfun)
    ## param after :: code to run after transaction signing. This code has access to the variable signedTransaction.
    ## This variable is of type SignTransaction
    ## param lastly :: code to run after transaction has been submitted. This code has access to variable 
    ## submittedTransaction of type SubmittedTransaction.
    
    var beforeVals {.inject.} = (
        max_gas_amount : DEFAULT_MAX_GAS_AMOUNT, 
        gas_price : (await client.estimateGasPrice()).prioritized_gas_estimate, 
        txn_duration : -1,
        payload : Payload(`type` : EntryFunction)
    )

    before

    let transaction = client.buildTransaction(
        account,
        beforeVals.max_gas_amount, 
        beforeVals.gas_price, 
        beforeVals.txn_duration
    )
    transaction.payload = beforeVals.payload

    var signedTransaction {.inject.} : SignTransaction
    when T is RefAptosAccount:
        
        sign()

    elif T is RefMultiSigAccount:

        let multiSigAccount = account
        multiSign()

    after
    
    let submittedTransaction {.inject.} = await client.submitTransaction(signedTransaction)
    account.incrementSeqNum()

    lastly

