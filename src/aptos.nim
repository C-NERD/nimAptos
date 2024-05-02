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
from std / uri import parseUri, UriParseError
from std / strutils import toLowerAscii

## third party import
import pkg / bcs

## project imports
import aptos / [account]
import aptos / utils as aptosutils
import aptos / api / [aptosclient, faucetclient, utils, nodetypes]
import aptos / aptostypes / [resourcetypes, moduleid, payload, transaction, signature]
import aptos / movetypes / [address, arguments]
#import aptos / ed25519 / ed25519

## project exports
export account, resourcetypes, moduleid, payload, transaction, address, arguments, aptosclient, faucetclient, nodetypes, bcs, utils, aptosutils

var DEFAULT_MAX_GAS_AMOUNT* = 10000 ## change this to what you want the default max gas amount to be

## extension procs to node api
template singleSign*[T : TransactionPayload](account : RefAptosAccount, client : AptosClient, transaction : RawTransaction[T], encoding : string = "") : untyped =
    
    var signedTransaction : SignTransaction[T]
    when defined(nodeSignature):

        ## encode transaction on the node
        signedTransaction = await signTransaction[T](account, client, transaction, encoding)

    else:

        signedTransaction = signTransaction[T](account, transaction, encoding)

    signedTransaction

template multiSign*[T : TransactionPayload](account : RefMultiSigAccount, client : AptosClient, transaction : RawTransaction[T], encoding : string = "") : untyped =
    
    var signedTransaction : SignTransaction[T]
    when defined(nodeSignature):

        ## encode transaction on the node
        signedTransaction = await multiSignTransaction[T](account, client, transaction, encoding)

    else:
        
        signedTransaction = multiSignTransaction[T](account, transaction, encoding)

    signedTransaction

proc validateGasFees*(client : AptosClient, max_gas_amount, gas_price : int64) : Future[tuple[max_gas_amount, gas_price : int64]] {.async.} =
    ## gas_price is in octa

    var
        max_gas_amount = max_gas_amount
        gas_price = gas_price

    if max_gas_amount < 0:

        max_gas_amount = DEFAULT_MAX_GAS_AMOUNT

    if gas_price < 0:

        let gasInfo = await client.estimateGasPrice()
        gas_price = gasInfo.prioritized_gas_estimate

    return (max_gas_amount, gas_price)

template transact*[T : TransactionPayload](account : RefAptosAccount | RefMultiSigAccount, client : AptosClient, payload : T, max_gas_amount, gas_price, txn_duration : int64) : untyped =
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
    ## sets result to SignTransaction 

    var fees = await validateGasFees(client, max_gas_amount, gas_price)
    var transaction = await buildTransaction[T](account, client, fees.max_gas_amount, fees.gas_price, txn_duration)
    transaction.payload = payload
    
    var signedTransaction : SignTransaction[T]
    when account is RefAptosAccount:

        signedTransaction = singleSign[T](account, client, transaction, "") 

    elif account is RefMultiSigAccount:

        signedTransaction = multiSign[T](account, client, transaction, "")
    
    await submitTransaction[T](client, signedTransaction)

template multiAgentTransact*[T : TransactionPayload](account : RefAptosAccount | RefMultiSigAccount, single_sec_signers : seq[RefAptosAccount], multi_sec_signers : seq[RefMultiSigAccount], client : AptosClient, payload : T, max_gas_amount, gas_price, txn_duration : int64) : untyped =
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

    var fees = await validateGasFees(client, max_gas_amount, gas_price)
    var transaction = await buildTransaction[T](account, client, fees.max_gas_amount, fees.gas_price, txn_duration)
    transaction.payload = payload
    
    var multiAgentTransaction = toMultiAgentRawTransaction[T](transaction)
    for signer in single_sec_signers:

        multiAgentTransaction.secondary_signers.add $signer.address

    for signer in multi_sec_signers:

        multiAgentTransaction.secondary_signers.add $signer.address
    
    var encodedTransaction : string
    when defined(nodeSignature):

        encodedTransaction = await client.encodeSubmission(multiAgentTransaction)
        
    else:
        
        encodedTransaction = "0x" & preHashMultiAgentTxn() & toLowerAscii($serialize[T](multiAgentTransaction))

    var signedTransaction : SignTransaction[T]
    when account is RefAptosAccount:

        signedTransaction = singleSign[T](account, client, transaction, encodedTransaction)

    elif account is RefMultiSigAccount:

        signedTransaction = multiSign[T](account, client, transaction, encodedTransaction)
    
    var 
        signerAddresses : seq[string]
        signerSignatures : seq[Signature]
    for signer in single_sec_signers:

        let singleSignedTxn = singleSign[T](signer, client, transaction, encodedTransaction)

        signerAddresses.add $signer.address
        signerSignatures.add singleSignedTxn.signature

    for signer in multiSigners:

        let multiSignedTxn = multiSign[T](signer, client, transaction, encodedTransaction)

        signerAddresses.add $signer.address
        signerSignatures.add multiSignedTxn.signature

    signedTransaction = multiAgentSignTransaction[T](
        signedTransaction.signature,
        signerSignatures,
        signerAddresses,
        transaction
    )
    await submitTransaction[T](client, signedTransaction)

proc sendAptCoin*(account : RefAptosAccount | RefMultiSigAccount, client : AptosClient, recipient : Address, 
    amount : float, max_gas_amount = -1; gas_price = -1; txn_duration : int64 = -1) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    ## param amount: amount to send in aptos
    ## txn_duration : amount of time in seconds till transaction timeout
    ## if < 0 then the library will handle it
    ## returns transaction
    
    let payload = EntryFunctionPayload(
        moduleid : newModuleId("0x1::coin"),
        function : "transfer",
        type_arguments : @["0x1::aptos_coin::AptosCoin"],
        arguments : @[eArg recipient, eArg (uint64(amount.toOcta()))]
    )
    result = transact[EntryFunctionPayload](account, client, payload, max_gas_amount, gas_price, txn_duration)
    
proc createCollection*(account : RefAptosAccount | RefMultiSigAccount, client : AptosClient, name, 
    description, uri : string, max_gas_amount = -1; gas_price = -1; txn_duration : int64 = -1) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    ## returns transaction 
    
    discard parseUri(uri) ## will raise UriParseError if not valid uri
    let payload = EntryFunctionPayload(
        moduleid : newModuleId("0x3::token"),
        function : "create_collection_script",
        type_arguments : @[],
        arguments : @[eArg name, eArg description, eArg uri, eArg high(uint64), eArg @[eArg false, eArg false, eArg false]]
    )
    result = transact[EntryFunctionPayload](account, client, payload, max_gas_amount, gas_price, txn_duration)

proc createToken*(account : RefAptosAccount | RefMultiSigAccount, client : AptosClient, collection, name, 
    description, uri : string, supply, royalty_pts_per_million : uint64, max_gas_amount = -1; gas_price = -1;
    txn_duration : int64 = -1) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    ## returns transaction
    
    discard parseUri(uri)
    let empty : seq[EntryArguments] = @[]
    let payload = EntryFunctionPayload(
        moduleid : newModuleId("0x3::token"),
        function : "create_token_script",
        type_arguments : @[],
        arguments : @[
            eArg collection, eArg name, eArg description, eArg supply, eArg supply, eArg uri, eArg account.address, 
            eArg uint64(1000000), eArg royalty_pts_per_million, eArg @[eArg false, eArg false, eArg false, eArg false, eArg false], 
            eArg empty, eArg empty, eArg empty
        ]
    )
    result = transact[EntryFunctionPayload](account, client, payload, max_gas_amount, gas_price, txn_duration)

proc offerToken*(account : RefAptosAccount | RefMultiSigAccount, client : AptosClient, recipient, creator : Address, 
    collection, token : string, property_version : uint64, amount : float, max_gas_amount = -1; gas_price = -1;
    txn_duration : int64 = -1) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    ## returns transaction

    let payload = EntryFunctionPayload(
        moduleid : newModuleId("0x3::token_transfers"),
        function : "offer_script",
        type_arguments : @[],
        arguments : @[
            eArg recipient, eArg creator, eArg collection, eArg token, eArg property_version, eArg uint64(amount.toOcta())
        ]
    )
    result = transact[EntryFunctionPayload](account, client, payload, max_gas_amount, gas_price, txn_duration)

proc claimToken*(account : RefAptosAccount | RefMultiSigAccount, client : AptosClient, sender, creator : Address,
    collection, token : string, property_version : uint64, max_gas_amount = -1; gas_price = -1;
    txn_duration : int64 = -1) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    ## returns transaction

    let payload = EntryFunctionPayload(
        moduleid : newModuleId("0x3::token_transfers"),
        function : "claim_script",
        type_arguments : @[],
        arguments : @[eArg sender, eArg creator, eArg collection, eArg token, eArg property_version]
    )
    result = transact[EntryFunctionPayload](account, client, payload, max_gas_amount, gas_price, txn_duration)

proc directTransferToken*(sender, recipient : RefAptosAccount | RefMultiSigAccount, client : AptosClient, 
    creator : Address, collection, token : string, property_version : uint64, amount : float, max_gas_amount = -1; gas_price = -1;
    txn_duration : int64 = -1) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    
    var
        singleSigners : seq[RefAptosAccount]
        multiSigners : seq[RefMultiSigAccount]
    when recipient is RefAptosAccount:

        singleSigners = @[recipient]

    elif recipient is RefMultiSigAccount:

        multiSigners = @[recipient]

    let payload = EntryFunctionPayload(
        moduleid : newModuleId("0x3::token"),
        function : "direct_transfer_script",
        type_arguments : @[],
        arguments : @[eArg creator, eArg collection, eArg token, eArg property_version, eArg uint64(amount.toOcta())]
    )
    result = multiAgentTransact[EntryFunctionPayload](sender, singleSigners, multiSigners, client, payload, max_gas_amount, gas_price, txn_duration)

proc registerAccount*(account : RefAptosAccount | RefMultiSigAccount, client : AptosClient, new_account : RefAptosAccount,
    max_gas_amount = -1; gas_price = -1; txn_duration : int64 = -1) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    ## register address for new wallet account
    ## returns transaction
    
    let payload = EntryFunctionPayload(
        moduleid : newModuleId("0x1::aptos_account"),
        function : "create_account",
        type_arguments : @[],
        arguments : @[eArg new_account.address]
    )
    result = transact[EntryFunctionPayload](account, client, payload, max_gas_amount, gas_price, txn_duration)

proc registerMultiSigAccount*(account : RefAptosAccount | RefMultiSigAccount, client : AptosClient, owners : seq[Address], num_of_sig_req : uint64,
    max_gas_amount = -1; gas_price = -1; txn_duration : int64 = -1) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    ## creates new multisig account with account as signer
    ## and owners as additional owners.
    ## make sure that account address is not repeated in owners param
    ## returns account address of new multisig account
    ## param threshold :: this is the number of signatures required
    
    let empty : seq[EntryArguments] = @[]
    var ownersArg : seq[EntryArguments]
    for owner in owners:

        ownersArg.add eArg owner
    
    let payload = EntryFunctionPayload(
        moduleid : newModuleId("0x1::multisig_account"),
        function : "create_with_owners_then_remove_bootstrapper",
        type_arguments : @[],
        arguments : @[
            eArg ownersArg, eArg num_of_sig_req, eArg empty, eArg empty
        ]
    )
    result = transact[EntryFunctionPayload](account, client, payload, max_gas_amount, gas_price, txn_duration)

proc publishPackage*(account : RefAptosAccount | RefMultiSigAccount,  client : AptosClient, 
    package_meta : openArray[byte], modules : openArray[seq[byte]], max_gas_amount = -1; gas_price = -1; txn_duration : int64 = -1) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    
    var modulesArg : seq[EntryArguments]
    for module in modules:

        modulesArg.add eArg fromBytes(module)

    let payload = EntryFunctionPayload(
        moduleid : newModuleId("0x1::code"),
        function : "publish_package_txn",
        type_arguments : @[],
        arguments : @[
            eArg fromBytes(package_meta), eArg modulesArg
        ]
    )
    result = transact[EntryFunctionPayload](account, client, payload, max_gas_amount, gas_price, txn_duration)


