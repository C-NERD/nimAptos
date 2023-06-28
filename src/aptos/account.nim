#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## This module implements procs to work with the RefAptosAccount object

when defined(js):

    {.fatal : "js backend is not implemented for account module".}

## std imports
import std / [asyncdispatch]
from std / re import match, re
from std / times import epochTime
from std / strformat import fmt
from std / strutils import toHex, toLowerAscii, parseInt
from std / json import JsonNode, newJString
#from std / sequtils import concat
from std / bitops import rotateLeftBits, bitor

## nimble imports
import sha3
from pkg / nimcrypto / utils import toHex, fromHex
from pkg / jsony import toJson, fromJson

## project imports
import ed25519 / ed25519
import datatype, api/nodehttp, aptosbcs

type

    InvalidSeed* = object of ValueError

    AccountCreationError* = object of CatchableError

    AptosAccount = object

        address*, seed*, publicKey, privateKey : string
        resource : AccountResource

    MultiSigAccount = object

        address* : string
        accounts* : seq[RefAptosAccount]
        resource : MultiSigAccountResource

    RefAptosAccount* = ref AptosAccount

    RefMultiSigAccount* = ref MultiSigAccount

const
    singleEd25519 : byte = 0
    multiEd25519 : byte = 1
    #guidObjectAddress : byte = 253
    #seedObjectAddress : byte = 254
    #resourceAccountAddress : byte = 255

proc isValidSeed*(seed : string) : bool = match seed, re"^((0x)?)([A-z]|[0-9]){64}$"

proc isPriKey*(key : string) : bool = match key, re"^((0x)?)([A-z]|[0-9]){128}$"

proc getPublicKey*(account : RefAptosAccount) : string = "0x" & account.publicKey

proc getPrivateKey*(account : RefAptosAccount) : string = "0x" & account.privateKey

proc incrementSeqNum*[T : RefAptosAccount | RefMultiSigAccount](account : T) =

    when T is RefAptosAccount:

        account.resource.sequence_number = $(parseInt(account.resource.sequence_number) + 1)

    elif T is RefMultiSigAccount:
        
        account.resource.last_executed_sequence_number = account.resource.next_sequence_number
        account.resource.next_sequence_number = $(parseInt(account.resource.next_sequence_number) + 1)

template signTransaction() =
    
    let signature = "0x" & signHex(account.privateKey, submission)
    assert verifyHex(account.publicKey, signature, submission), fmt"cannot verify signature for 0x" & account.publicKey
    result.signature = Signature(
        `type` : SingleSignature,
        public_key : "0x" & account.publicKey,
        signature : "0x" & signHex(account.privateKey, submission)
    )

template multiSignTransaction() =
    
    var 
        publicKeys : seq[string]
        signatures : seq[string]
        rawBitMap = 0
    for pos in 0..<len(account.accounts):
        
        let 
            pubkey = "0x" & account.accounts[pos].publicKey
            signature = "0x" & signHex(account.accounts[pos].privateKey, submission)

        publicKeys.add pubkey
        signatures.add signature
        
        assert verifyHex(pubkey, signature, submission), "cannot verify signature for " & pubkey
        
        let shift = 31 - pos
        rawBitMap = bitor(rawBitMap, int(rotateLeftBits(1'u, shift)))

    let bitMap = cast[array[4, byte]](rawBitMap) ## 4 bytes endian bit map
    result.signature = datatype.Signature(
        `type` : MultiSignature,
        public_keys : publicKeys,
        signatures : signatures,
        bitmap : "0x" & utils.toHex(bitMap, true),
        threshold : parseInt(account.resource.num_signatures_required)
    )

template multiAgentSignTransaction() =

    result.signature = datatype.Signature(
        `type` : MultiAgentSignature,
        secondary_signer_addresses : signerAddresses,
        sender : senderSignature,
        secondary_signers : secondarySigners
    )

proc signTransaction*(account : RefAptosAccount, client : RefAptosClient, transaction : RawTransaction, encodedTxn : string = "") : Future[SignTransaction] {.async.} =
    ## signs transaction by encoding transaction to bcs on the node
    ## then signing it locally

    result = transaction 
    var submission : string
    if len(encodedTxn) == 0:

        submission = await client.encodeSubmission(transaction)

    else:

        submission = encodedTxn

    #echo submission, "\n"
    signTransaction()

proc multiSignTransaction*(account : RefMultiSigAccount, client : RefAptosClient, transaction : RawTransaction, encodedTxn : string = "") : Future[SignTransaction] {.async.} =
     
    result = transaction
    var submission : string
    if len(encodedTxn) == 0:

        submission = await client.encodeSubmission(transaction)

    else:

        submission = encodedTxn

    multiSignTransaction()

proc multiAgentSignTransaction*(sender_sig : Signature, secondary_signers : seq[Signature], 
    signer_addrs : seq[string], transaction : RawTransaction) : SignTransaction =

    result = transaction
    var  
        signerAddresses : seq[string] = signer_addrs
        secondarySigners : seq[Signature] = secondary_signers
        senderSignature : ref Signature
    
    new(senderSignature)
    senderSignature[] = sender_sig

    #let submission = await client.encodeSubmission(transaction)
    multiAgentSignTransaction()

proc signTransaction*(account : RefAptosAccount, transaction : RawTransaction) : SignTransaction =
    ## signs transaction by encoding transaction to bcs locally
    ## then signing it locally

    result = transaction
    
    let submission : string = block:

        var ctx: SHA3
        let bcsTxn = "APTOS::RawTransaction"
        sha3_init(ctx, SHA3_256)
        sha3_update(ctx, bcsTxn, len(bcsTxn))
        
        let 
            preHash = sha3_final(ctx)
            submission = utils.toHex(preHash, true) & toLowerAscii(encodeTransaction(transaction))

        submission
    
    #echo submission, "\n"
    signTransaction()

proc buildTransaction*[T : RefAptosAccount | RefMultiSigAccount](client : RefAptosClient, account : T, max_gas_amount, gas_price, txn_duration : int64 = -1) : RawTransaction =
    ## params :
    ## 
    ## account          -> account to build transaction for
    ## max_gas_amount   -> maximum amount of gas that can be sent for this transaction
    ## gas_price        -> price in octa unit per gas
    ## txn_duration     -> amount of time in seconds till transaction timeout
    var 
        duration = txn_duration
        sequenceNumber : string
    if duration < 0:

        duration = 18000 ## set to 5 hours

    when T is RefAptosAccount:

        sequenceNumber = account.resource.sequence_number

    elif T is RefMultiSigAccount:

        sequenceNumber = account.resource.next_sequence_number
    
    result = RawTransaction(
        chain_id : client.getNodeInfo().chain_id,
        sender : account.address,
        sequence_number : sequenceNumber,
        expiration_timestamp_secs : $(int64(epochTime()) + duration),
    )

    if max_gas_amount >= 0:

        result.max_gas_amount = $max_gas_amount

    if gas_price >= 0:

        result.gas_unit_price = $gasPrice

## account util procs
proc getAddressFromKey*(pubkey : string) : string =
    ## gets address from public key
    ## for single Ed25519 accounts
    
    if not isValidSeed(pubkey):

        raise newException(InvalidSeed, fmt"public key {pubkey} is invalid")

    let publicKey = utils.fromHex(pubkey)
    var ctx : SHA3
    sha3_init(ctx, SHA3_256)
    sha3_update(ctx, publicKey, len(publicKey))
    sha3_update(ctx, singleEd25519, 1)

    return "0x" & utils.toHex(sha3_final(ctx), true)

proc getAddressFromKeys*(keys : seq[string], threshold : range[1..32]) : string =
    ## gets address from public keys
    ## for multi sig accounts
    
    let keyNum = len(keys)
    if keyNum < 2 or keyNum > 32:

        raise newException(IndexDefect, "len of keys sequence should be >= 2 and <= 32")

    for key in keys:

        if not isValidSeed(key):

            raise newException(InvalidSeed, fmt"public key {key} is invalid")
    
    var publicKeysConcat : seq[byte]
    for key in keys:

        publicKeysConcat.add utils.fromHex(key)

    publicKeysConcat.add byte(threshold)

    var ctx : SHA3
    sha3_init(ctx, SHA3_256)
    sha3_update(ctx, publicKeysConcat, len(publicKeysConcat))
    sha3_update(ctx, multiEd25519, 1)

    return "0x" & utils.toHex(sha3_final(ctx), true)

proc accountExists*(client : RefAptosClient, address : string) : Future[bool] {.async.} =

    let resp = await client.executeModuleView(
        ViewRequest(
            function : "0x1::account::exists_at",
            type_arguments : @[],
            arguments : @[newJString(address)]
        )
    )
    return resp.fromJson(seq[bool])[0]

## initialization procs for type RefAptosAccount and RefMultiSigAccount
proc newAccount*(client : RefAptosClient, address, seed : string, getres : bool = true) : 
    RefAptosAccount =
    ## The seed is your 32 bytes | 64 character private key
    
    if not isValidSeed(seed):

        raise newException(InvalidSeed, fmt"seed {seed} is invalid")
    
    let keypair = getKeyPair(seed)
    result = RefAptosAccount(
        address : address,
        publicKey : keypair.pubkey,
        privateKey : keypair.prvkey,
        seed : seed 
    ) 

    if getres:

        result.resource = waitFor client.getAccount(address)

proc accountFromKey*(client : RefAptosClient, address, prikey : string) : RefAptosAccount =

    if not isPriKey(prikey):

        raise newException(InvalidSeed, fmt"private key {prikey} is invalid")

    let seed = getSeed(prikey)
    return newAccount(client, address, seed)

proc newMultiSigAccount*(client : RefAptosClient, accounts : seq[RefAptosAccount], address : string, 
    getres : bool = true) : RefMultiSigAccount =

    result = RefMultiSigAccount(
        address : address,
        accounts : accounts
    )

    if getres:

        let resource = waitFor client.getAccountResource(address, MultiSigAccountResourceType)
        assert resource.`type` == MultiSigAccountResourceType, "Invalid resource type"

        result.resource = resource.multi_acct_data

proc refreashAccount*[T : RefAptosAccount | RefMultiSigAccount](client : RefAptosClient, account : T) =
    
    when T is RefAptosAccount:

        account.resource = waitFor client.getAccount(address)

    elif T is RefMultiSigAccount:

        let resource = waitFor client.getAccountResource(address, MultiSigAccountResourceType)
        assert resource.`type` == MultiSigAccountResourceType, "Invalid resource type"

        account.resource = resource.multi_acct_data

proc createWallet*(client : RefAptosClient) : RefAptosAccount =
    ## This proc only creates a new random keypair and seed hash
    ## and it initializes a new RefAptosAccount object
    ## it does not how ever register the new wallet with the
    ## aptos blockchain. 
    ## To do this use the faucet node to get APT into the wallet
    ## or call the aptos move function `0x1::aptos_account::create_account`.
    ## or call the registerAccount proc in the aptos.nim file
    ## NOTE :: registeration of account is chain specific. Which means registeration on
    ## devnet will not show on mainnet and vice versa
    
    var seed, address : string
    while true:

        seed = "0x" & toHex(@(randomSeed()), true)
        let keyPair = getKeyPair(seed)
        address = getAddressFromKey(keyPair.pubkey)
    
        if not waitFor(client.accountExists(address)):

            break
    
    result = client.newAccount(address, seed, false)

proc createMultiSigWallet*(client : RefAptosClient, accounts : seq[RefAptosAccount], threshold : range[1..32]) : RefMultiSigAccount {.deprecated.} =
    ## This proc only creates a new address from the given aptos accounts
    ## and it initializes a new RefMultiSigAccount object.
    ## It does not how ever register the new wallet with the
    ## aptos blockchain.
    ## you can register new wallet by using the faucet to send funds to account
    ## Because of the way the aptos move function to create multisig account works,
    ## this proc has been deprecated.
    ## It's going to be here so that you can play with it.

    var keys : seq[string]
    for acct in accounts:

        keys.add acct.publicKey
    
    let address = getAddressFromKeys(keys, threshold)
    if waitFor(client.accountExists(address)):

        raise newException(AccountCreationError, fmt"account at address {address} already exists")
 
    result = client.newMultiSigAccount(accounts, address, false)

