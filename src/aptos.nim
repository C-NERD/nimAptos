#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## This module implements top level sugars for basic tasks on the aptos blockchain.
## It also exports all other modules of this library except the sugar module

## std imports
import std / [asyncdispatch, json]
from std / uri import parseUri, UriParseError
#from std / strutils import toLowerAscii, toHex

## third party import
import pkg / bcs

## project imports
import aptos / sugars
import aptos / accounts / [account]
import aptos / utils as aptosutils
import aptos / api / [aptosclient, faucetclient, utils, nodetypes]
import aptos / aptostypes / [resourcetypes, transaction]
import aptos / movetypes / [address, arguments, multisig_creation_message, rotation_challenge, typeinfo]
import aptos / aptostypes / payload / [payload, moduleid]
import aptos / aptostypes / authenticator / [authenticator, signature, publickey]

## project exports
export account, resourcetypes, moduleid, payload, transaction, aptosclient, faucetclient, nodetypes, utils, aptosutils, bcs
export address, arguments, multisig_creation_message, rotation_challenge, typeinfo
export authenticator, signature, publickey

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
        arguments : @[extendedEArg name, extendedEArg description, extendedEArg uri, eArg high(uint64), extendedEArg(@[eArg false, eArg false, eArg false])]
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
            extendedEArg collection, extendedEArg name, extendedEArg description, eArg supply, eArg supply, extendedEArg uri, eArg account.address, 
            eArg uint64(1000000), eArg royalty_pts_per_million, extendedEArg(@[eArg false, eArg false, eArg false, eArg false, eArg false]),
            extendedEArg(empty), extendedEArg(empty), extendedEArg(empty)
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
            eArg recipient, eArg creator, extendedEArg collection, extendedEArg token, eArg property_version, eArg uint64(amount.toOcta())
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
        arguments : @[eArg sender, eArg creator, extendedEArg collection, extendedEArg token, eArg property_version]
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
        arguments : @[eArg creator, extendedEArg collection, extendedEArg token, eArg property_version, eArg uint64(amount.toOcta())]
    )
    result = multiAgentTransact[EntryFunctionPayload](sender, singleSigners, multiSigners, client, payload, max_gas_amount, gas_price, txn_duration)

proc rotationProofChallenge*(accountForm1, accountForm2 : RefAptosAccount | RefMultiSigAccount, client : AptosClient,
    max_gas_amount = -1; gas_price = -1; txn_duration : int64 = -1) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    ## rotation proof challenge
    
    refresh(accountForm1, client)
    refresh(accountForm2, client)

    var 
        fromScheme, toScheme : uint8
        sequenceNumber : uint64
        originator, currentAuthKey : Address
    when accountForm1 is RefAptosAccount:

        fromScheme = SINGLE_ED25519_SIG_ENUM
        sequenceNumber = accountForm1.sequence_number
        originator = accountForm1.address
        currentAuthKey = initAddress(accountForm1.authentication_key)

    elif accountForm1 is RefMultiSigAccount:

        fromScheme = MULTI_ED25519_SIG_ENUM
        sequenceNumber = accountForm1.sequence_number #accountForm1.last_executed_sequence_number
        originator = accountForm1.address
        currentAuthKey = initAddress(accountForm1.authentication_key)

    when accountForm2 is RefAptosAccount:

        toScheme = SINGLE_ED25519_SIG_ENUM

    elif accountForm2 is RefMultiSigAccount:

        toScheme = MULTI_ED25519_SIG_ENUM

    let 
        challenge = initRotationProofChallenge(
            sequenceNumber,
            originator,
            currentAuthKey,
            fromString(accountForm2.getPublicKey())
        )
        ## package and serialize as type info :: Required
        challengeTypeInfo = initTypeInfo[RotationProofChallenge](
            initAddress("0x1"),
            "account",
            "RotationProofChallenge",
            challenge
        )
        serChallengeTypeInfo = serialize[RotationProofChallenge](challengeTypeInfo, rotation_challenge.serialize)
    var capRotateKey, capUpdateTable : HexString
    when accountForm1 is RefAptosAccount:

        let sig = accountForm1.signMsg($serChallengeTypeInfo) 
        capRotateKey = initSingleSignature(sig)
        assert accountForm1.verifySignature($capRotateKey, $serChallengeTypeInfo), "unable to verify accountForm1 single signature"

    elif accountForm1 is RefMultiSigAccount:
        
        var 
            singleSignatures : seq[SingleEd25519Signature]
            positions : seq[int]
        let signature = accountForm1.signMsg($serChallengeTypeInfo)
        assert accountForm1.verifySignature(signature, $serChallengeTypeInfo), "unable to verify accountForm1 multi signature"
        for sig in signature:

            singleSignatures.add initSingleSignature(sig.signature)
            positions.add sig.ownerpos

        capRotateKey = serialize(initMultiSignature(singleSignatures, positions))

    when accountForm2 is RefAptosAccount:

        let sig2 = accountForm2.signMsg($serChallengeTypeInfo)
        capUpdateTable = initSingleSignature(sig2)
        assert accountForm2.verifySignature($capUpdateTable, $serChallengeTypeInfo), "unable to verify accountForm2 single signature"

    elif accountForm2 is RefMultiSigAccount:

        var 
            singleSignatures : seq[SingleEd25519Signature]
            positions : seq[int]
        let signature2 = accountForm2.signMsg($serChallengeTypeInfo)
        assert accountForm2.verifySignature(signature2, $serChallengeTypeInfo), "unable to verify accountForm2 multi signature"
        for sig in signature2:

            singleSignatures.add initSingleSignature(sig.signature)
            positions.add sig.ownerpos

        capUpdateTable = serialize(initMultiSignature(singleSignatures, positions))

    let
        payload = EntryFunctionPayload(
            moduleid : newModuleId("0x1::account"),
            function : "rotate_authentication_key",
            type_arguments : @[],
            arguments : @[
                eArg fromScheme, eArg fromString(accountForm1.getPublicKey()),
                eArg toScheme, eArg fromString(accountForm2.getPublicKey()),
                eArg capRotateKey, eArg capUpdateTable
            ]
        )
    result = transact[EntryFunctionPayload](accountForm1, client, payload, max_gas_amount, gas_price, txn_duration)

proc registerAccount*(account : RefAptosAccount | RefMultiSigAccount, client : AptosClient, new_account : RefAptosAccount | RefMultiSigAccount,
    max_gas_amount = -1; gas_price = -1; txn_duration : int64 = -1) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    ## register address for new wallet
    ## returns transaction
    
    let payload = EntryFunctionPayload(
        moduleid : newModuleId("0x1::aptos_account"),
        function : "create_account",
        type_arguments : @[],
        arguments : @[eArg new_account.address]
    )
    result = transact[EntryFunctionPayload](account, client, payload, max_gas_amount, gas_price, txn_duration)

proc registerMultiSigAcctFromExistingAcct*(account : RefAptosAccount | RefMultiSigAccount, client : AptosClient, new_account : RefAptosAccount | RefMultiSigAccount,
    owners : seq[RefAptosAccount], num_signatures_required : uint64,
    max_gas_amount = -1; gas_price = -1; txn_duration : int64 = -1) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    ## did not call refresh here cause it is assumed that new_account maybe an unregistered RefMultiSigAccount
    ## you may need to call refresh manually on this
    
    var 
        empty : seq[EntryArguments]
        ownersArg : seq[EntryArguments]
        ownersAddr : seq[Address]
    for owner in owners:

        ownersArg.add eArg owner.address
        ownersAddr.add owner.address

    var sequenceNumber : uint64
    when new_account is RefAptosAccount:

        sequenceNumber = new_account.sequence_number
    
    elif new_account is RefMultiSigAccount:

        sequenceNumber = new_account.sequence_number #new_account.last_executed_sequence_number

    let 
        creationMsg = initMultiSigCreationMessage(
            new_account.address,
            client,
            ownersAddr,
            sequenceNumber,
            num_signatures_required
        )
        ## package and serialize as type info :: Required
        creationMsgTypeInfo = initTypeInfo[MultiSigCreationMessage](
            initAddress("0x1"),
            "multisig_account",
            "MultisigAccountCreationMessage",
            creationMsg
        )
        serCreationMsgTypeInfo = serialize[MultiSigCreationMessage](creationMsgTypeInfo, multisig_creation_message.serialize)
        accountSig = signMsg(new_account, $serCreationMsgTypeInfo)

    var payload : EntryFunctionPayload
    when new_account is RefAptosAccount:

        payload = EntryFunctionPayload(
            moduleid : newModuleId("0x1::multisig_account"),
            function : "create_with_existing_account",
            type_arguments : @[],
            arguments : @[
                eArg new_account.address, extendedEArg ownersArg, eArg num_signatures_required,
                eArg SINGLE_ED25519_SIG_ENUM, eArg fromString(new_account.getPublicKey()), 
                eArg initSingleSignature(fromString(accountSig)),
                extendedEArg(empty), extendedEArg(empty)
            ]
        )

    elif new_account is RefMultiSigAccount:
        
        var
            signatures : seq[SingleEd25519Signature]
            positions : seq[int]
        for sig in accountSig:
            
            signatures.add fromString(sig.signature)
            positions.add sig.ownerpos

        let multiSignature = initMultiSignature(signatures, positions)
        payload = EntryFunctionPayload(
            moduleid : newModuleId("0x1::multisig_account"),
            function : "create_with_existing_account",
            type_arguments : @[],
            arguments : @[
                eArg new_account.address, extendedEArg ownersArg, eArg num_signatures_required,
                eArg MULTI_ED25519_SIG_ENUM, eArg fromString(new_account.getPublicKey()),
                eArg serialize(multiSignature),
                extendedEArg(empty), extendedEArg(empty)
            ]
        )
    result = transact[EntryFunctionPayload](account, client, payload, max_gas_amount, gas_price, txn_duration)

#[proc publishPackage*(account : RefAptosAccount | RefMultiSigAccount,  client : AptosClient, seed : string,
    package_meta : openArray[byte], modules : openArray[seq[byte]], max_gas_amount = -1; gas_price = -1; txn_duration : int64 = -1
) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    
    var modulesArg : seq[EntryArguments]
    for module in modules:

        modulesArg.add eArg fromBytes(module)

    let payload = EntryFunctionPayload(
        moduleid : newModuleId("0x1::resource_account"),
        function : "create_resource_account_and_publish_package",
        type_arguments : @[],
        arguments : @[
            eArg fromString(seed), eArg fromBytes(package_meta), extendedEArg(modulesArg)
        ]
    )
    result = transact[EntryFunctionPayload](account, client, payload, max_gas_amount, gas_price, txn_duration)

proc publishPackage*(package_path : string, account : RefAptosAccount | RefMultiSigAccount,  client : AptosClient,
    max_gas_amount = -1; gas_price = -1; txn_duration : int64 = -1) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =

    proc readMeta(path : string) : seq[byte] {.closure.} =

        discard

    proc readModules(build_path : string) : seq[seq[byte]] {.closure.} =

        discard
    
    let
        meta : seq[byte] = readMeta("")
        modules : seq[seq[byte]] = readModules("")

    return account.publishPackage(client, meta, modules, max_gas_amount, gas_price, txn_duration)]#

## RefMultiSigAccount specific sugars
proc multiSigSendAptCoin*(owner : RefAptosAccount, account : RefMultiSigAccount, client : AptosClient, recipient : Address, 
    amount : float, max_gas_amount = -1; gas_price = -1; txn_duration : int64 = -1) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    ## param amount: amount to send in aptos
    ## txn_duration : amount of time in seconds till transaction timeout
    ## if < 0 then the library will handle it
    ## returns transaction
    
    var payload = EntryFunctionPayload(
        moduleid : newModuleId("0x1::coin"),
        function : "transfer",
        type_arguments : @["0x1::aptos_coin::AptosCoin"],
        arguments : @[eArg recipient, eArg (uint64(amount.toOcta()))]
    )
    payload = createMultiSigTransaction(account, serializeEntryFunction(payload))
    result = transact[EntryFunctionPayload](owner, client, payload, max_gas_amount, gas_price, txn_duration)

proc multiSigTxnVote*(owner : RefAptosAccount, account : RefMultiSigAccount, client : AptosClient, sequenceNumber : uint64, 
    vote : Vote, max_gas_amount = -1; gas_price = -1; txn_duration : int64 = -1) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =

    let payload = voteOnTransaction(account, sequenceNumber, vote)
    result = transact[EntryFunctionPayload](owner, client, payload, max_gas_amount, gas_price, txn_duration)

proc removeRejectedTxns*(owner : RefAptosAccount, account : RefMultiSigAccount, client : AptosClient, finalSequenceNumber : uint64, 
    max_gas_amount = -1; gas_price = -1; txn_duration : int64 = -1) : Future[SubmittedTransaction[EntryFunctionPayload]] {.async.} =

    let payload = removeRejectedTransactions(account, finalSequenceNumber)
    result = transact[EntryFunctionPayload](owner, client, payload, max_gas_amount, gas_price, txn_duration)

