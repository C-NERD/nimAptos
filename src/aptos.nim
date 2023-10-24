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
import aptos / [account, utils]
import aptos / api / [aptosclient, faucetclient]
import aptos / datatype / [move, payload, signature, change, event, transaction, writeset]

## project exports
export account, utils, aptosclient, faucetclient, move, payload, signature, change, event, transaction, writeset

##
var DEFAULT_MAX_GAS_AMOUNT* = 10000 ## change this to what you want the default max gas
## amount to be

## extension procs to node api
template sign*(encodedTxn : string = "") =
    ## encodes and signs transaction as single ed25519 transaction
    ## params sync :: should nodeSignature be syncronous (true) or asyncronous (false)
    ## requires ::
    ## variable account : RefAptosAccount
    ## variable client : AptosClient (only required when `nodeSignature` is defined)
    ## variable transaction : RawTransaction
    ## to be defined 
    #when defined(nodeSignature):
    ## encode transaction on the node
    signedTransaction = signTransaction(account, transaction, encodedTxn)
    signedTransaction = await signTransaction(account, client, transaction, encodedTxn)

    #else:

    #signedTransaction = signTransaction(account, transaction, encodedTxn)

template multiSign*(encodedTxn : string = "") =
    ## encodes and signs transaction as multi ed25519 transaction
    ## params sync :: should nodeSignature be syncronous (true) or asyncronous (false)
    ## requires ::
    ## variable account : RefMultiSigAccount
    ## variable client : AptosClient (only required when `nodeSignature` is defined)
    ## variable transaction : RawTransaction
    ## to be defined
    when defined(nodeSignature):
        ## encode transaction on the node

        signedTransaction = await multiSignTransaction(account, client, transaction, encodedTxn)

    else:
        
        {.fatal : "local bcs signing for multisig account not yet implemented".}

template validateGasFees*() {.dirty.} =
    ## gas_price is in octa

    var
        max_gas_amount = max_gas_amount
        gas_price = gas_price

    if max_gas_amount < 0:

        max_gas_amount = DEFAULT_MAX_GAS_AMOUNT

    if gas_price < 0:

        let gasInfo = await client.estimateGasPrice()
        gas_price = gasInfo.prioritized_gas_estimate

proc accountBalanceApt*[T : RefAptosAccount | RefMultiSigAccount](client : AptosClient, 
    account : T) : Future[float] {.async.} =

    let resource = await client.getAccountResource(account.address, AptCoinResourceType)
    return parseInt(resource.coin_data.coin.value).toApt()

template transact*(customcode : untyped) : untyped =
    ## required variables
    ## client : (AptosClient)
    ## account : account initiating transaction (RefAptosAccount | RefMultiSigAccount)
    ## max_gas_amount : maximum gas amount permitted (int64)
    ## gas_price : gas price to be used for transaction (int64)
    ## txn_duration : duration for transaction timeout in seconds(int64)
    ##
    ## injects:
    ## var transaction : RawTransaction
    ## var signedTransaction (for other tmpl called)
    ## 
    ## sets result to SubmittedTransaction 

    validateGasFees()
    var transaction {.inject.} = await buildTransaction(account, client, max_gas_amount, gas_price, txn_duration)
    
    customcode

    var signedTransaction {.inject.} : SignTransaction
    when T is RefAptosAccount:

        sign()

    elif T is RefMultiSigAccount:

        multiSign()

    result = await client.submitTransaction(signedTransaction)

    #[nnkStmtList.newTree(
        nnkIfStmt.newTree(
            nnkElifBranch.newTree(
                nnkPrefix.newTree(
                    newIdentNode("not"),
                    nnkCall.newTree(
                        newIdentNode("isValidSeed"),
                        newIdentNode("recipient")
                    )
                ),

                nnkStmtList.newTree(
                    nnkRaiseStmt.newTree(
                        nnkCall.newTree(
                            newIdentNode("newException"),
                            newIdentNode("InvalidSeed"),
                            nnkCallStrLit.newTree(
                                newIdentNode("fmt"),
                                newLit("recipient\'s address {recipient} is invalid")
                            )
                        )
                    )
                )
            )
        ),

        nnkCall.newTree(newIdentNode("validateGasFees")),

        nnkVarSection.newTree(
            nnkIdentDefs.newTree(
                newIdentNode("transaction"),
                newEmptyNode(),
                nnkCommand.newTree(
                    newIdentNode("await"),
                    nnkCall.newTree(
                        nnkDotExpr.newTree(
                            newIdentNode("account"),
                            newIdentNode("buildTransaction")
                        ),

                        newIdentNode("client"),
                        newIdentNode("max_gas_amount"),
                        newIdentNode("gas_price"),
                        newIdentNode("txn_duration")
                    )
                )
            )
        ),

        customcode,

        nnkVarSection.newTree(
            nnkIdentDefs.newTree(
                newIdentNode("signedTransaction"),
                newIdentNode("SignTransaction"),
                newEmptyNode()
            )
        ),

        nnkWhenStmt.newTree(
            nnkElifBranch.newTree(
                nnkInfix.newTree(
                    newIdentNode("is"),
                    newIdentNode("T"),
                    newIdentNode("RefAptosAccount")
                ),

                nnkStmtList.newTree(
                    nnkCall.newTree(newIdentNode("sign"))
                )
            ),

            nnkElifBranch.newTree(
                nnkInfix.newTree(
                    newIdentNode("is"),
                    newIdentNode("T"),
                    newIdentNode("RefMultiSigAccount")
                ),

                nnkStmtList.newTree(
                    nnkCall.newTree(newIdentNode("multiSign"))
                )
            )
        ),

        nnkReturnStmt.newTree(
            nnkPar.newTree(
                nnkCommand.newTree(
                    newIdentNode("await"),
                    nnkCall.newTree(
                        nnkDotExpr.newTree(
                            newIdentNode("client"),
                            newIdentNode("submitTransaction")
                        ),
                        newIdentNode("signedTransaction")
                    )
                )
            )
        )
    )]#

template multiAgentTransact*(customcode : untyped) : untyped =
    ## like transact tmpl, but for multiagent transactions
    ## required variables
    ## client : (AptosClient)
    ## sender : sender's account object (RefAptosAccount | RefMultiSigAccount)
    ## singleSigners : seq of signers seq[RefAptosAccount]
    ## multiSigners : seq of signers seq[RefMultiSigAccount]
    ## signers : seq of all signers address seq[string]
    ## NOTE :: this template assumes that the first account in accounts is the sender.
    ## max_gas_amount : maximum gas amount permitted (int64)
    ## gas_price : gas price to be used for transaction (int64)
    ## txn_duration : duration for transaction timeout in seconds(int64)
    ##
    ## injects:
    ## var transaction : RawTransaction
    ## var signedTransaction (for other tmpl called)
    ## let account (for sign and multisign tmpl)
    ## 
    ## sets result to SubmittedTransaction 

    validateGasFees()
    var transaction {.inject.} = await buildTransaction(sender, client, max_gas_amount, gas_price, txn_duration)
    
    customcode
    
    var multiAgentTransaction = toMultiAgentRawTransaction(transaction)
    multiAgentTransaction.secondary_signers = signers
    when defined(nodeSignature):

        let encodedTransaction = await client.encodeSubmission(multiAgentTransaction)

    else:
        
        #let encodedTransaction = ""
        {.fatal : "local transaction encoding not implemented yet".}

    var signedTransaction {.inject.} : SignTransaction
    when sender is RefAptosAccount:

        let account {.inject.} = sender
        sign(encodedTransaction)

    elif sender is RefMultiSigAccount:

        let account {.inject.} = sender
        multiSign(encodedTransaction)

    let senderSig = signedTransaction.signature ## set sender's signature
    var 
        signerAddresses : seq[string]
        signerSignatures : seq[Signature]
    for signer in singleSigners:

        let account {.inject.} = signer
        sign(encodedTransaction)

        signerAddresses.add account.address
        signerSignatures.add signedTransaction.signature

    for signer in multiSigners:

        let account {.inject.} = signer
        multiSign(encodedTransaction)

        signerAddresses.add account.address
        signerSignatures.add signedTransaction.signature

    signedTransaction = multiAgentSignTransaction(
        senderSig, 
        signerSignatures,
        signerAddresses,
        transaction
    )
    result = await client.submitTransaction(signedTransaction)

proc sendAptCoin*[T : RefAptosAccount | RefMultiSigAccount](client : AptosClient, account : T, recipient : string, 
    amount : float, max_gas_amount, gas_price, txn_duration : int64 = -1) : Future[SubmittedTransaction] {.async.} =
    ## param amount: amount to send in aptos
    ## txn_duration : amount of time in seconds till transaction timeout
    ## if < 0 then the library will handle it
    ## returns transaction
    
    if not isValidSeed(recipient):

        raise newException(InvalidSeed, fmt"recipient's address {recipient} is invalid")

    transact:

        transaction.payload = Payload(
            `type` : EntryFunction,
            function : "0x1::coin::transfer",
            entry_type_arguments : @["0x1::aptos_coin::AptosCoin"],
            entry_arguments : toPayloadArgs((recipient, $(amount.toOcta())))
        )

proc createCollection*[T : RefAptosAccount | RefMultiSigAccount](client : AptosClient, account : T, name, 
    description, uri : string, max_gas_amount, gas_price, txn_duration : int64 = -1) : Future[SubmittedTransaction] {.async.} =
    ## returns transaction 

    transact:

        transaction.payload = Payload(
            `type` : EntryFunction,
            function : "0x3::token::create_collection_script",
            entry_type_arguments : @[],
            entry_arguments : toPayloadArgs((name, description, uri, $high(uint64)), @[false, false, false])
        )

proc createToken*[T : RefAptosAccount | RefMultiSigAccount](client : AptosClient, account : T, collection, name, 
    description, uri : string, supply, royalty_pts_per_million : uint64, max_gas_amount, gas_price,
    txn_duration : int64 = -1) : Future[SubmittedTransaction] {.async.} =
    ## returns transaction

    transact:
        
        transaction.payload = Payload(
            `type` : EntryFunction,
            function : "0x3::token::create_token_script",
            entry_type_arguments : @[],
            entry_arguments : toPayloadArgs((collection, name, description, $supply, $supply, uri, account.address, $1000000, $royalty_pts_per_million, @[false, false, false, false, false], @[], @[], @[]))
        )

proc offerToken*[T : RefAptosAccount | RefMultiSigAccount](client : AptosClient, account : T, recipient, creator, 
    collection, token : string, property_version, amount : uint64, max_gas_amount, gas_price,
    txn_duration : int64 = -1) : Future[SubmittedTransaction] {.async.} =
    ## returns transaction
    
    if not isValidSeed(recipient):

        raise newException(InvalidSeed, fmt"recipient's address {recipient} is invalid")

    if not isValidSeed(creator):

        raise newException(InvalidSeed, fmt"creator's address {creator} is invalid")

    transact:

        transaction.payload = Payload(
            `type` : EntryFunction,
            function : "0x3::token_transfers::offer_script",
            entry_type_arguments : @[],
            entry_arguments : toPayloadArgs((recipient, creator, collection, token, $property_version, $amount))
        )

proc claimToken*[T : RefAptosAccount | RefMultiSigAccount](client : AptosClient, account : T, sender, 
    creator, collection, token : string, property_version : uint64, max_gas_amount, gas_price,
    txn_duration : int64 = -1) : Future[SubmittedTransaction] {.async.} =
    ## returns transaction
    
    if not isValidSeed(sender):

        raise newException(InvalidSeed, fmt"sender's address {sender} is invalid")

    if not isValidSeed(creator):

        raise newException(InvalidSeed, fmt"creator's address {creator} is invalid")

    transact:

        transaction.payload = Payload(
            `type` : EntryFunction,
            function : "0x3::token_transfers::claim_script",
            entry_type_arguments : @[],
            entry_arguments : toPayloadArgs((sender, creator, collection, token, $property_version))
        )

proc directTransferToken*[T, K : RefAptosAccount | RefMultiSigAccount](client : AptosClient, sender : T, recipient : K, 
    creator, collection, token : string, property_version, amount : uint64, max_gas_amount, gas_price,
    txn_duration : int64 = -1) : Future[SubmittedTransaction] {.async.} =

    if not isValidSeed(creator):

        raise newException(InvalidSeed, fmt"creator's address {creator} is invalid")
    
    let signers = @[recipient.address]
    var
        singleSigners : seq[RefAptosAccount]
        multiSigners : seq[RefMultiSigAccount]
    when K is RefAptosAccount:

        singleSigners = @[recipient]

    elif K is RefMultiSigAccount:

        multiSigners = @[recipient]

    multiAgentTransact:

        transaction.payload = Payload(
            `type` : EntryFunction,
            function : "0x3::token::direct_transfer_script",
            entry_type_arguments : @[],
            entry_arguments : toPayloadArgs((creator, collection, token, $property_version, $amount))
        )     

proc registerAccount*[T : RefAptosAccount | RefMultiSigAccount](client : AptosClient, account : T, address : string, 
    max_gas_amount, gas_price, txn_duration : int64 = -1) : Future[SubmittedTransaction] {.async.} =
    ## register address for new wallet account
    ## returns transaction

    if not isValidSeed(address):

        raise newException(InvalidSeed, fmt"address {address} is invalid")
    
    transact:

        transaction.payload = Payload(
            `type` : EntryFunction,
            function : "0x1::aptos_account::create_account",
            entry_type_arguments : @[],
            entry_arguments : toPayloadArgs(address)
        )

#[proc registerMultiSigAccount*[T : RefAptosAccount | RefMultiSigAccount](client : AptosClient, account : T, owners : seq[string], threshold : int,
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

    return userTransaction.user_events[0].guid.account_address]#

proc publishPackage*[T : RefAptosAccount | RefMultiSigAccount](client : AptosClient, account : T, 
    package_meta : openArray[byte], modules : seq[openArray[byte]]) : Future[string] {.async.} =

    discard

