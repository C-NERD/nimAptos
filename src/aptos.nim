#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## This module implements top level sugars for basic tasks on the aptos blockchain.
## It also exports all other modules of this library except the sugar module
## To better understand the code implementations here, Pls glance through code in the aptosStdLib.
## aptosStdLib can be found in modules of account `0x1` and `0x3` on the aptos blockchain
## or in aptos-core git repo

## std imports
import std / [asyncdispatch, json]
from std / uri import parseUri, UriParseError

## third party import
import pkg / bcs

## project imports
import aptos / sugars
import aptos / accounts / [account]
import aptos / utils as aptosutils
import aptos / api / [aptosclient, faucetclient, utils, nodetypes]
import aptos / aptostypes / [resourcetypes, transaction]
import aptos / movetypes / [address, arguments, multisig_creation_message,
        rotation_challenge, typeinfo]
import aptos / aptostypes / payload / [payload, moduleid]
import aptos / aptostypes / authenticator / [authenticator, signature, publickey]

## project exports
export account, resourcetypes, moduleid, payload, transaction, aptosclient,
        faucetclient, nodetypes, utils, aptosutils, bcs
export address, arguments, multisig_creation_message, rotation_challenge, typeinfo
export authenticator, signature, publickey

proc sendAptCoin*(account: RefAptosAccount | RefMultiSigAccount,
        client: AptosClient, recipient: Address,
    amount: float, max_gas_amount = -1; gas_price = -1;
            txn_duration: int64 = -1): Future[SubmittedTransaction[
            EntryFunctionPayload]] {.async.} =
    ## param amount: amount to send in aptos
    ## txn_duration : amount of time in seconds till transaction timeout
    ## if < 0 then the library will handle it
    ## returns transaction

    let payload = EntryFunctionPayload(
        moduleid: newModuleId("0x1::coin"),
        function: "transfer",
        type_arguments: @["0x1::aptos_coin::AptosCoin"],
        arguments: @[eArg recipient, eArg (uint64(amount.toOcta()))]
    )
    result = transact[EntryFunctionPayload](account, client, payload,
            max_gas_amount, gas_price, txn_duration)

proc createCollection*(account: RefAptosAccount | RefMultiSigAccount,
        client: AptosClient, name,
    description, uri: string, maximum: uint64, collection_mutability: array[3,
            bool], max_gas_amount = -1; gas_price = -1;
            txn_duration: int64 = -1): Future[SubmittedTransaction[
            EntryFunctionPayload]] {.async.} =
    ## collection_mutability specifies which part of the collection is mutable;
    ## pos 1 : collection description
    ## pos 2 : collection uri
    ## pos 3 : collection maximum
    ## These are from the consts defined in the 0x3::token smart contract

    discard parseUri(uri) ## will raise UriParseError if not valid uri
    let collectionMutability = block:

        var mut: seq[EntryArguments]
        for pos in 0..<len(collection_mutability):

            mut.add eArg collection_mutability[pos]

        mut

    let payload = EntryFunctionPayload(
        moduleid: newModuleId("0x3::token"),
        function: "create_collection_script",
        type_arguments: @[],
        arguments: @[extendedEArg name, extendedEArg description,
                extendedEArg uri, eArg maximum,
                extendedEArg collectionMutability]
    )
    result = transact[EntryFunctionPayload](account, client, payload,
            max_gas_amount, gas_price, txn_duration)

proc createToken*(account: RefAptosAccount | RefMultiSigAccount,
        client: AptosClient, collection, name,
    description, uri: string, balance, maximum, royalty_pts_denominator,
            royalty_pts_numerator: uint64, token_mutability: array[5, bool],
            max_gas_amount = -1; gas_price = -1;
    txn_duration: int64 = -1): Future[SubmittedTransaction[
            EntryFunctionPayload]] {.async.} =
    ## token_mutability specifies which part of the token is mutable;
    ## pos 1 : token maximum
    ## pos 2 : token uri
    ## pos 3 : token royalty
    ## pos 4 : token description
    ## pos 5 : token property
    ## pos 6 : token property_value NOTE :: this is currently not accounted for in token_mutability param as I did not see it in the declared struct on the smart contract
    ## but it was declared as a const. So keep in mind
    ## These are from the consts defined in the 0x3::token smart contract

    discard parseUri(uri) ## should throw error on invalid uri
    let empty: seq[EntryArguments] = @[]
    let tokenMutability = block:

        var mut: seq[EntryArguments]
        for pos in 0..<len(token_mutability):

            mut.add eArg token_mutability[pos]

        mut

    let payload = EntryFunctionPayload(
        moduleid: newModuleId("0x3::token"),
        function: "create_token_script",
        type_arguments: @[],
        arguments: @[
            extendedEArg collection, extendedEArg name,
            extendedEArg description, eArg balance, eArg maximum,
            extendedEArg uri, eArg account.address,
            eArg royalty_pts_denominator, eArg royalty_pts_numerator,
            extendedEArg tokenMutability,
            extendedEArg(empty), extendedEArg(empty), extendedEArg(empty)
        ]
    )
    result = transact[EntryFunctionPayload](account, client, payload,
            max_gas_amount, gas_price, txn_duration)

proc offerToken*(account: RefAptosAccount | RefMultiSigAccount,
        client: AptosClient, recipient, creator: Address,
    collection, token: string, property_version: uint64, amount: uint64,
            max_gas_amount = -1; gas_price = -1;
    txn_duration: int64 = -1): Future[SubmittedTransaction[
            EntryFunctionPayload]] {.async.} =
    ## returns transaction

    let payload = EntryFunctionPayload(
        moduleid: newModuleId("0x3::token_transfers"),
        function: "offer_script",
        type_arguments: @[],
        arguments: @[
            eArg recipient, eArg creator, extendedEArg collection,
            extendedEArg token, eArg property_version, eArg amount
        ]
    )
    result = transact[EntryFunctionPayload](account, client, payload,
            max_gas_amount, gas_price, txn_duration)

proc claimToken*(account: RefAptosAccount | RefMultiSigAccount,
        client: AptosClient, sender, creator: Address,
    collection, token: string, property_version: uint64, max_gas_amount = -1;
            gas_price = -1;
    txn_duration: int64 = -1): Future[SubmittedTransaction[
            EntryFunctionPayload]] {.async.} =
    ## returns transaction

    let payload = EntryFunctionPayload(
        moduleid: newModuleId("0x3::token_transfers"),
        function: "claim_script",
        type_arguments: @[],
        arguments: @[eArg sender, eArg creator, extendedEArg collection,
                extendedEArg token, eArg property_version]
    )
    result = transact[EntryFunctionPayload](account, client, payload,
            max_gas_amount, gas_price, txn_duration)

proc directTransferToken*(sender, recipient: RefAptosAccount |
        RefMultiSigAccount, client: AptosClient,
    creator: Address, collection, token: string, property_version: uint64,
            amount: uint64, max_gas_amount = -1; gas_price = -1;
    txn_duration: int64 = -1): Future[SubmittedTransaction[
            EntryFunctionPayload]] {.async.} =

    var
        singleSigners: seq[RefAptosAccount]
        multiSigners: seq[RefMultiSigAccount]
    when recipient is RefAptosAccount:

        singleSigners = @[recipient]

    elif recipient is RefMultiSigAccount:

        multiSigners = @[recipient]

    let payload = EntryFunctionPayload(
        moduleid: newModuleId("0x3::token"),
        function: "direct_transfer_script",
        type_arguments: @[],
        arguments: @[eArg creator, extendedEArg collection, extendedEArg token,
                eArg property_version, eArg amount]
    )
    result = multiAgentTransact[EntryFunctionPayload](sender, singleSigners,
            multiSigners, client, payload, max_gas_amount, gas_price, txn_duration)

proc rotationProofChallenge*(accountForm1, accountForm2: RefAptosAccount |
        RefMultiSigAccount, client: AptosClient,
    max_gas_amount = -1; gas_price = -1; txn_duration: int64 = -1): Future[
            SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    ## rotation proof challenge

    await refresh(accountForm1, client)
    await refresh(accountForm2, client)

    var
        fromScheme, toScheme: uint8
        sequenceNumber: uint64
        originator, currentAuthKey: Address
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
        serChallengeTypeInfo = serialize(challengeTypeInfo)
    var capRotateKey, capUpdateTable: HexString
    when accountForm1 is RefAptosAccount:

        let sig = accountForm1.signMsg($serChallengeTypeInfo)
        capRotateKey = initSingleSignature(sig)
        assert accountForm1.verifySignature($capRotateKey,
                $serChallengeTypeInfo), "unable to verify accountForm1 single signature"

    elif accountForm1 is RefMultiSigAccount:

        var
            singleSignatures: seq[SingleEd25519Signature]
            positions: seq[int]
        let signature = accountForm1.signMsg($serChallengeTypeInfo)
        assert accountForm1.verifySignature(signature, $serChallengeTypeInfo), "unable to verify accountForm1 multi signature"
        for sig in signature:

            singleSignatures.add initSingleSignature(sig.signature)
            positions.add sig.ownerpos

        capRotateKey = serialize(initMultiSignature(singleSignatures, positions))

    when accountForm2 is RefAptosAccount:

        let sig2 = accountForm2.signMsg($serChallengeTypeInfo)
        capUpdateTable = initSingleSignature(sig2)
        assert accountForm2.verifySignature($capUpdateTable,
                $serChallengeTypeInfo), "unable to verify accountForm2 single signature"

    elif accountForm2 is RefMultiSigAccount:

        var
            singleSignatures: seq[SingleEd25519Signature]
            positions: seq[int]
        let signature2 = accountForm2.signMsg($serChallengeTypeInfo)
        assert accountForm2.verifySignature(signature2, $serChallengeTypeInfo), "unable to verify accountForm2 multi signature"
        for sig in signature2:

            singleSignatures.add initSingleSignature(sig.signature)
            positions.add sig.ownerpos

        capUpdateTable = serialize(initMultiSignature(singleSignatures, positions))

    let
        payload = EntryFunctionPayload(
            moduleid: newModuleId("0x1::account"),
            function: "rotate_authentication_key",
            type_arguments: @[],
            arguments: @[
                eArg fromScheme, eArg fromString(accountForm1.getPublicKey()),
                eArg toScheme, eArg fromString(accountForm2.getPublicKey()),
                eArg capRotateKey, eArg capUpdateTable
            ]
        )
    result = transact[EntryFunctionPayload](accountForm1, client, payload,
            max_gas_amount, gas_price, txn_duration)

proc registerAccount*(account: RefAptosAccount | RefMultiSigAccount,
        client: AptosClient, new_account: RefAptosAccount | RefMultiSigAccount,
    max_gas_amount = -1; gas_price = -1; txn_duration: int64 = -1): Future[
            SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    ## register address for new wallet
    ## returns transaction

    let payload = EntryFunctionPayload(
        moduleid: newModuleId("0x1::aptos_account"),
        function: "create_account",
        type_arguments: @[],
        arguments: @[eArg new_account.address]
    )
    result = transact[EntryFunctionPayload](account, client, payload,
            max_gas_amount, gas_price, txn_duration)

proc registerMultiSigAcctFromExistingAcct*(account: RefAptosAccount |
        RefMultiSigAccount, client: AptosClient, new_account: RefAptosAccount |
        RefMultiSigAccount,
    owners: seq[RefAptosAccount], num_signatures_required: uint64,
    max_gas_amount = -1; gas_price = -1; txn_duration: int64 = -1): Future[
            SubmittedTransaction[EntryFunctionPayload]] {.async.} =
    ## did not call refresh here cause it is assumed that new_account maybe an unregistered RefMultiSigAccount
    ## you may need to call refresh manually on this

    var
        empty: seq[EntryArguments]
        ownersArg: seq[EntryArguments]
        ownersAddr: seq[Address]
    for owner in owners:

        ownersArg.add eArg owner.address
        ownersAddr.add owner.address

    var sequenceNumber: uint64
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
        serCreationMsgTypeInfo = serialize(creationMsgTypeInfo)
        accountSig = signMsg(new_account, $serCreationMsgTypeInfo)

    var payload: EntryFunctionPayload
    when new_account is RefAptosAccount:

        payload = EntryFunctionPayload(
            moduleid: newModuleId("0x1::multisig_account"),
            function: "create_with_existing_account",
            type_arguments: @[],
            arguments: @[
                eArg new_account.address, extendedEArg ownersArg,
                eArg num_signatures_required,
                eArg SINGLE_ED25519_SIG_ENUM, eArg fromString(
                        new_account.getPublicKey()),
                eArg initSingleSignature(fromString(accountSig)),
                extendedEArg(empty), extendedEArg(empty)
            ]
        )

    elif new_account is RefMultiSigAccount:

        var
            signatures: seq[SingleEd25519Signature]
            positions: seq[int]
        for sig in accountSig:

            signatures.add fromString(sig.signature)
            positions.add sig.ownerpos

        let multiSignature = initMultiSignature(signatures, positions)
        payload = EntryFunctionPayload(
            moduleid: newModuleId("0x1::multisig_account"),
            function: "create_with_existing_account",
            type_arguments: @[],
            arguments: @[
                eArg new_account.address, extendedEArg ownersArg,
                eArg num_signatures_required,
                eArg MULTI_ED25519_SIG_ENUM, eArg fromString(
                        new_account.getPublicKey()),
                eArg serialize(multiSignature),
                extendedEArg(empty), extendedEArg(empty)
            ]
        )
    result = transact[EntryFunctionPayload](account, client, payload,
            max_gas_amount, gas_price, txn_duration)

## RefMultiSigAccount specific sugars
proc multiSigSendAptCoin*(owner: RefAptosAccount, account: RefMultiSigAccount,
        client: AptosClient, recipient: Address,
    amount: float, max_gas_amount = -1; gas_price = -1;
            txn_duration: int64 = -1): Future[SubmittedTransaction[
            EntryFunctionPayload]] {.async.} =
    ## param amount: amount to send in aptos
    ## txn_duration : amount of time in seconds till transaction timeout
    ## if < 0 then the library will handle it
    ## returns transaction

    var payload = EntryFunctionPayload(
        moduleid: newModuleId("0x1::coin"),
        function: "transfer",
        type_arguments: @["0x1::aptos_coin::AptosCoin"],
        arguments: @[eArg recipient, eArg (uint64(amount.toOcta()))]
    )
    payload = createMultiSigTransaction(account, serialize(payload))
    result = transact[EntryFunctionPayload](owner, client, payload,
            max_gas_amount, gas_price, txn_duration)

proc multiSigTxnVote*(owner: RefAptosAccount, account: RefMultiSigAccount,
        client: AptosClient, sequenceNumber: uint64,
    vote: Vote, max_gas_amount = -1; gas_price = -1;
            txn_duration: int64 = -1): Future[SubmittedTransaction[
            EntryFunctionPayload]] {.async.} =

    let payload = voteOnTransaction(account, sequenceNumber, vote)
    result = transact[EntryFunctionPayload](owner, client, payload,
            max_gas_amount, gas_price, txn_duration)

proc removeRejectedTxns*(owner: RefAptosAccount, account: RefMultiSigAccount,
        client: AptosClient, finalSequenceNumber: uint64,
    max_gas_amount = -1; gas_price = -1; txn_duration: int64 = -1): Future[
            SubmittedTransaction[EntryFunctionPayload]] {.async.} =

    let payload = removeRejectedTransactions(account, finalSequenceNumber)
    result = transact[EntryFunctionPayload](owner, client, payload,
            max_gas_amount, gas_price, txn_duration)

when defined(simulateTxn):

    proc simulateSendAptCoin*(account: RefAptosAccount | RefMultiSigAccount,
            client: AptosClient, recipient: Address,
        amount: float, max_gas_amount = -1; gas_price = -1;
                txn_duration: int64 = -1): Future[JsonNode] {.async.} =
        ## param amount: amount to send in aptos
        ## txn_duration : amount of time in seconds till transaction timeout
        ## if < 0 then the library will handle it
        ## returns transaction

        let payload = EntryFunctionPayload(
            moduleid: newModuleId("0x1::coin"),
            function: "transfer",
            type_arguments: @["0x1::aptos_coin::AptosCoin"],
            arguments: @[eArg recipient, eArg (uint64(amount.toOcta()))]
        )
        result = transact[EntryFunctionPayload](account, client, payload,
                max_gas_amount, gas_price, txn_duration)
        
    proc simulateCreateCollection*(account: RefAptosAccount | RefMultiSigAccount,
            client: AptosClient, name,
        description, uri: string, maximum: uint64, collection_mutability: array[3,
                bool], max_gas_amount = -1; gas_price = -1;
                txn_duration: int64 = -1): Future[JsonNode] {.async.} =
        ## collection_mutability specifies which part of the collection is mutable;
        ## pos 1 : collection description
        ## pos 2 : collection uri
        ## pos 3 : collection maximum
        ## These are from the consts defined in the 0x3::token smart contract

        discard parseUri(uri) ## will raise UriParseError if not valid uri
        let collectionMutability = block:

            var mut: seq[EntryArguments]
            for pos in 0..<len(collection_mutability):

                mut.add eArg collection_mutability[pos]

            mut

        let payload = EntryFunctionPayload(
            moduleid: newModuleId("0x3::token"),
            function: "create_collection_script",
            type_arguments: @[],
            arguments: @[extendedEArg name, extendedEArg description,
                    extendedEArg uri, eArg maximum,
                    extendedEArg collectionMutability]
        )
        result = transact[EntryFunctionPayload](account, client, payload,
                max_gas_amount, gas_price, txn_duration)

    proc simulateCreateToken*(account: RefAptosAccount | RefMultiSigAccount,
            client: AptosClient, collection, name,
        description, uri: string, balance, maximum, royalty_pts_denominator,
                royalty_pts_numerator: uint64, token_mutability: array[5, bool],
                max_gas_amount = -1; gas_price = -1;
        txn_duration: int64 = -1): Future[JsonNode] {.async.} =
        ## token_mutability specifies which part of the token is mutable;
        ## pos 1 : token maximum
        ## pos 2 : token uri
        ## pos 3 : token royalty
        ## pos 4 : token description
        ## pos 5 : token property
        ## pos 6 : token property_value NOTE :: this is currently not accounted for in token_mutability param as I did not see it in the declared struct on the smart contract
        ## but it was declared as a const. So keep in mind
        ## These are from the consts defined in the 0x3::token smart contract

        discard parseUri(uri) ## should throw error on invalid uri
        let empty: seq[EntryArguments] = @[]
        let tokenMutability = block:

            var mut: seq[EntryArguments]
            for pos in 0..<len(token_mutability):

                mut.add eArg token_mutability[pos]

            mut

        let payload = EntryFunctionPayload(
            moduleid: newModuleId("0x3::token"),
            function: "create_token_script",
            type_arguments: @[],
            arguments: @[
                extendedEArg collection, extendedEArg name,
                extendedEArg description, eArg balance, eArg maximum,
                extendedEArg uri, eArg account.address,
                eArg royalty_pts_denominator, eArg royalty_pts_numerator,
                extendedEArg tokenMutability,
                extendedEArg(empty), extendedEArg(empty), extendedEArg(empty)
            ]
        )
        result = transact[EntryFunctionPayload](account, client, payload,
                max_gas_amount, gas_price, txn_duration)

    proc simulateOfferToken*(account: RefAptosAccount | RefMultiSigAccount,
            client: AptosClient, recipient, creator: Address,
        collection, token: string, property_version: uint64, amount: uint64,
                max_gas_amount = -1; gas_price = -1;
        txn_duration: int64 = -1): Future[JsonNode] {.async.} =
        ## returns transaction

        let payload = EntryFunctionPayload(
            moduleid: newModuleId("0x3::token_transfers"),
            function: "offer_script",
            type_arguments: @[],
            arguments: @[
                eArg recipient, eArg creator, extendedEArg collection,
                extendedEArg token, eArg property_version, eArg amount
            ]
        )
        result = transact[EntryFunctionPayload](account, client, payload,
                max_gas_amount, gas_price, txn_duration)

    proc simulateClaimToken*(account: RefAptosAccount | RefMultiSigAccount,
            client: AptosClient, sender, creator: Address,
        collection, token: string, property_version: uint64, max_gas_amount = -1;
                gas_price = -1;
        txn_duration: int64 = -1): Future[JsonNode] {.async.} =
        ## returns transaction

        let payload = EntryFunctionPayload(
            moduleid: newModuleId("0x3::token_transfers"),
            function: "claim_script",
            type_arguments: @[],
            arguments: @[eArg sender, eArg creator, extendedEArg collection,
                    extendedEArg token, eArg property_version]
        )
        result = transact[EntryFunctionPayload](account, client, payload,
                max_gas_amount, gas_price, txn_duration)

    proc simulateDirectTransferToken*(sender, recipient: RefAptosAccount |
            RefMultiSigAccount, client: AptosClient,
        creator: Address, collection, token: string, property_version: uint64,
                amount: uint64, max_gas_amount = -1; gas_price = -1;
        txn_duration: int64 = -1): Future[JsonNode] {.async.} =

        var
            singleSigners: seq[RefAptosAccount]
            multiSigners: seq[RefMultiSigAccount]
        when recipient is RefAptosAccount:

            singleSigners = @[recipient]

        elif recipient is RefMultiSigAccount:

            multiSigners = @[recipient]

        let payload = EntryFunctionPayload(
            moduleid: newModuleId("0x3::token"),
            function: "direct_transfer_script",
            type_arguments: @[],
            arguments: @[eArg creator, extendedEArg collection, extendedEArg token,
                    eArg property_version, eArg amount]
        )
        result = multiAgentTransact[EntryFunctionPayload](sender, singleSigners,
                multiSigners, client, payload, max_gas_amount, gas_price, txn_duration)

    proc simulateRotationProofChallenge*(accountForm1, accountForm2: RefAptosAccount |
            RefMultiSigAccount, client: AptosClient,
        max_gas_amount = -1; gas_price = -1; txn_duration: int64 = -1): Future[JsonNode] {.async.} =
        ## rotation proof challenge

        await refresh(accountForm1, client)
        await refresh(accountForm2, client)

        var
            fromScheme, toScheme: uint8
            sequenceNumber: uint64
            originator, currentAuthKey: Address
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
            serChallengeTypeInfo = serialize(challengeTypeInfo)
        var capRotateKey, capUpdateTable: HexString
        when accountForm1 is RefAptosAccount:

            let sig = accountForm1.signMsg($serChallengeTypeInfo)
            capRotateKey = initSingleSignature(sig)
            assert accountForm1.verifySignature($capRotateKey,
                    $serChallengeTypeInfo), "unable to verify accountForm1 single signature"

        elif accountForm1 is RefMultiSigAccount:

            var
                singleSignatures: seq[SingleEd25519Signature]
                positions: seq[int]
            let signature = accountForm1.signMsg($serChallengeTypeInfo)
            assert accountForm1.verifySignature(signature, $serChallengeTypeInfo), "unable to verify accountForm1 multi signature"
            for sig in signature:

                singleSignatures.add initSingleSignature(sig.signature)
                positions.add sig.ownerpos

            capRotateKey = serialize(initMultiSignature(singleSignatures, positions))

        when accountForm2 is RefAptosAccount:

            let sig2 = accountForm2.signMsg($serChallengeTypeInfo)
            capUpdateTable = initSingleSignature(sig2)
            assert accountForm2.verifySignature($capUpdateTable,
                    $serChallengeTypeInfo), "unable to verify accountForm2 single signature"

        elif accountForm2 is RefMultiSigAccount:

            var
                singleSignatures: seq[SingleEd25519Signature]
                positions: seq[int]
            let signature2 = accountForm2.signMsg($serChallengeTypeInfo)
            assert accountForm2.verifySignature(signature2, $serChallengeTypeInfo), "unable to verify accountForm2 multi signature"
            for sig in signature2:

                singleSignatures.add initSingleSignature(sig.signature)
                positions.add sig.ownerpos

            capUpdateTable = serialize(initMultiSignature(singleSignatures, positions))

        let
            payload = EntryFunctionPayload(
                moduleid: newModuleId("0x1::account"),
                function: "rotate_authentication_key",
                type_arguments: @[],
                arguments: @[
                    eArg fromScheme, eArg fromString(accountForm1.getPublicKey()),
                    eArg toScheme, eArg fromString(accountForm2.getPublicKey()),
                    eArg capRotateKey, eArg capUpdateTable
                ]
            )
        result = transact[EntryFunctionPayload](accountForm1, client, payload,
                max_gas_amount, gas_price, txn_duration)

    proc simulateRegisterAccount*(account: RefAptosAccount | RefMultiSigAccount,
            client: AptosClient, new_account: RefAptosAccount | RefMultiSigAccount,
        max_gas_amount = -1; gas_price = -1; txn_duration: int64 = -1): Future[JsonNode] {.async.} =
        ## register address for new wallet
        ## returns transaction

        let payload = EntryFunctionPayload(
            moduleid: newModuleId("0x1::aptos_account"),
            function: "create_account",
            type_arguments: @[],
            arguments: @[eArg new_account.address]
        )
        result = transact[EntryFunctionPayload](account, client, payload,
                max_gas_amount, gas_price, txn_duration)

    proc simulateRegisterMultiSigAcctFromExistingAcct*(account: RefAptosAccount |
            RefMultiSigAccount, client: AptosClient, new_account: RefAptosAccount |
            RefMultiSigAccount,
        owners: seq[RefAptosAccount], num_signatures_required: uint64,
        max_gas_amount = -1; gas_price = -1; txn_duration: int64 = -1): Future[JsonNode] {.async.} =
        ## did not call refresh here cause it is assumed that new_account maybe an unregistered RefMultiSigAccount
        ## you may need to call refresh manually on this

        var
            empty: seq[EntryArguments]
            ownersArg: seq[EntryArguments]
            ownersAddr: seq[Address]
        for owner in owners:

            ownersArg.add eArg owner.address
            ownersAddr.add owner.address

        var sequenceNumber: uint64
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
            serCreationMsgTypeInfo = serialize(creationMsgTypeInfo)
            accountSig = signMsg(new_account, $serCreationMsgTypeInfo)

        var payload: EntryFunctionPayload
        when new_account is RefAptosAccount:

            payload = EntryFunctionPayload(
                moduleid: newModuleId("0x1::multisig_account"),
                function: "create_with_existing_account",
                type_arguments: @[],
                arguments: @[
                    eArg new_account.address, extendedEArg ownersArg,
                    eArg num_signatures_required,
                    eArg SINGLE_ED25519_SIG_ENUM, eArg fromString(
                            new_account.getPublicKey()),
                    eArg initSingleSignature(fromString(accountSig)),
                    extendedEArg(empty), extendedEArg(empty)
                ]
            )

        elif new_account is RefMultiSigAccount:

            var
                signatures: seq[SingleEd25519Signature]
                positions: seq[int]
            for sig in accountSig:

                signatures.add fromString(sig.signature)
                positions.add sig.ownerpos

            let multiSignature = initMultiSignature(signatures, positions)
            payload = EntryFunctionPayload(
                moduleid: newModuleId("0x1::multisig_account"),
                function: "create_with_existing_account",
                type_arguments: @[],
                arguments: @[
                    eArg new_account.address, extendedEArg ownersArg,
                    eArg num_signatures_required,
                    eArg MULTI_ED25519_SIG_ENUM, eArg fromString(
                            new_account.getPublicKey()),
                    eArg serialize(multiSignature),
                    extendedEArg(empty), extendedEArg(empty)
                ]
            )
        result = transact[EntryFunctionPayload](account, client, payload,
                max_gas_amount, gas_price, txn_duration)

    ## RefMultiSigAccount specific simulation sugars
    proc simulateMultiSigSendAptCoin*(owner: RefAptosAccount, account: RefMultiSigAccount,
            client: AptosClient, recipient: Address,
        amount: float, max_gas_amount = -1; gas_price = -1;
                txn_duration: int64 = -1): Future[JsonNode] {.async.} =
        ## param amount: amount to send in aptos
        ## txn_duration : amount of time in seconds till transaction timeout
        ## if < 0 then the library will handle it
        ## returns transaction

        var payload = EntryFunctionPayload(
            moduleid: newModuleId("0x1::coin"),
            function: "transfer",
            type_arguments: @["0x1::aptos_coin::AptosCoin"],
            arguments: @[eArg recipient, eArg (uint64(amount.toOcta()))]
        )
        payload = createMultiSigTransaction(account, serialize(payload))
        result = transact[EntryFunctionPayload](owner, client, payload,
                max_gas_amount, gas_price, txn_duration)

    proc simulateMultiSigTxnVote*(owner: RefAptosAccount, account: RefMultiSigAccount,
            client: AptosClient, sequenceNumber: uint64,
        vote: Vote, max_gas_amount = -1; gas_price = -1;
                txn_duration: int64 = -1): Future[JsonNode] {.async.} =

        let payload = voteOnTransaction(account, sequenceNumber, vote)
        result = transact[EntryFunctionPayload](owner, client, payload,
                max_gas_amount, gas_price, txn_duration)

    proc simulateRemoveRejectedTxns*(owner: RefAptosAccount, account: RefMultiSigAccount,
            client: AptosClient, finalSequenceNumber: uint64,
        max_gas_amount = -1; gas_price = -1; txn_duration: int64 = -1): Future[JsonNode] {.async.} =

        let payload = removeRejectedTransactions(account, finalSequenceNumber)
        result = transact[EntryFunctionPayload](owner, client, payload,
                max_gas_amount, gas_price, txn_duration)
