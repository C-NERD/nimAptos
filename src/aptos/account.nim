#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## This module implements procs to work with the RefAptosAccount and RefMultiSigAccount object

when defined(js):

    {.fatal : "js backend is not implemented for account module".}

## std imports
import std / [asyncdispatch]
from std / re import match, re
from std / times import epochTime
from std / strformat import fmt
from std / strutils import toLowerAscii, parseInt, isEmptyOrWhitespace
from std / json import getStr, `[]`
from std / bitops import rotateLeftBits, bitor
from std / options import some

## nimble imports
import pkg / [sha3]
import pkg / nimcrypto / utils as cryptoutils
from pkg / jsony import fromJson

## project imports
import ed25519 / ed25519
import api / [utils, aptosclient, nodetypes]
import aptostypes / [signature, transaction, payload]
import movetypes / [address]
import utils

type

    InvalidSeed* = object of ValueError

    AccountCreationError* = object of CatchableError

    AptosAccount = ref object of RootObj

        address* : Address

    RefAptosAccount* = ref object of AptosAccount

        seed*, publicKey, privateKey : string 
        sequence_number*, guid_creation_num* : int
        authentication_key* : string

    RefMultiSigAccount* = ref object of AptosAccount

        accounts* : seq[RefAptosAccount]
        last_executed_sequence_number*, next_sequence_number*, num_signatures_required* : int

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

proc refresh(account : var RefAptosAccount | var RefMultiSigAccount, client : AptosClient) {.async.} =

    when account is RefAptosAccount:

        let resource = await client.getAccountResource($account.address, "0x1::account::Account")
        account.sequence_number = parseInt(getStr(resource.data["sequence_number"]))
        account.authentication_key = getStr(resource.data["authentication_key"])
        account.guid_creation_num = parseInt(getStr(resource.data["guid_creation_num"]))

    elif account is RefMultiSigAccount:

        let resource = await client.getAccountResource($account.address, "0x1::multisig_account::MultisigAccount")
        account.last_executed_sequence_number = parseInt(getStr(resource.data["last_executed_sequence_number"]))
        account.next_sequence_number = parseInt(getStr(resource.data["next_sequence_number"]))
        account.num_signatures_required = parseInt(getStr(resource.data["num_signatures_required"]))

template signTransaction() =
    
    #echo submission ## using this to debug bcs encoding of transaction
    let signature = "0x" & signHex(account.privateKey, submission)
    assert verifyHex(account.publicKey, signature, submission), fmt"cannot verify signature for 0x" & account.publicKey
    result.signature = Signature(
        `type` : SingleSignature,
        public_key : "0x" & account.publicKey,
        signature : signature
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

    #await account.refresh(client)
    let threshold = account.num_signatures_required

    result.signature = Signature(
        `type` : MultiSignature,
        public_keys : publicKeys,
        signatures : signatures,
        bitmap : "0x" & toHex(bitMap, true),
        threshold : threshold
    )

proc signTransaction*[T : TransactionPayload](account : RefAptosAccount, client : AptosClient, transaction : RawTransaction[T], encodedTxn : string = "") : Future[SignTransaction[T]] {.async.} =
    ## signs transaction by encoding transaction to bcs on the node
    ## then signing it locally
    
    result = toSignTransaction[T](transaction)
    var submission : string
    if encodedTxn.isEmptyOrWhitespace():

        submission = await client.encodeSubmission(transaction)

    else:

        submission = encodedTxn

    signTransaction()

proc multiSignTransaction*[T : TransactionPayload](account : RefMultiSigAccount, client : AptosClient, transaction : RawTransaction[T], encodedTxn : string = "") : Future[SignTransaction[T]] {.async.} =
     
    result = toSignTransaction[T](transaction)
    var submission : string
    if encodedTxn.isEmptyOrWhitespace():

        submission = await client.encodeSubmission(transaction)

    else:

        submission = encodedTxn

    multiSignTransaction()

proc preHashMultiAgentTxn*() : string =

    var ctx: SHA3
    let bcsTxn = "APTOS::RawTransactionWithData"
    sha3_init(ctx, SHA3_256)
    sha3_update(ctx, bcsTxn, len(bcsTxn))

    let preHash = sha3_final(ctx)
    return toHex(preHash, true)

proc multiAgentSignTransaction*[T : TransactionPayload](sender_sig : Signature, secondary_signers : seq[Signature], 
    signer_addrs : seq[string], transaction : RawTransaction[T]) : SignTransaction[T] =

    result = toSignTransaction[T](transaction)
    var  
        signerAddresses : seq[string] = signer_addrs
        secondarySigners : seq[Signature] = secondary_signers
        senderSignature : ref Signature
    
    new(senderSignature)
    senderSignature[] = sender_sig
    result.signature = Signature(
        `type` : MultiAgentSignature,
        secondary_signer_addresses : signerAddresses,
        sender : senderSignature,
        secondary_signers : secondarySigners
    )

template preHashRawTxn() : untyped =

    var ctx: SHA3
    let bcsTxn = "APTOS::RawTransaction"
    sha3_init(ctx, SHA3_256)
    sha3_update(ctx, bcsTxn, len(bcsTxn))

    sha3_final(ctx)

proc signTransaction*[T : TransactionPayload](account : RefAptosAccount, transaction : RawTransaction[T], encodedTxn : string = "") : SignTransaction[T] =
    ## signs transaction by encoding transaction to bcs locally
    ## then signing it locally
    
    result = toSignTransaction[T](transaction)
    var submission : string
    if encodedTxn.isEmptyOrWhitespace():

        let preHash = preHashRawTxn()    
        submission = "0x" & toHex(preHash, true) & toLowerAscii($serialize(transaction))

    else:

        submission = encodedTxn
    
    signTransaction()

template preHashMultiSigTxn() : untyped =

    var ctx: SHA3
    let bcsTxn = "APTOS::RawTransaction"
    sha3_init(ctx, SHA3_256)
    sha3_update(ctx, bcsTxn, len(bcsTxn))

    sha3_final(ctx)

proc multiSignTransaction*[T : TransactionPayload](account : RefMultiSigAccount, transaction : RawTransaction[T], encodedTxn : string = "") : SignTransaction[T] =
     
    result = toSignTransaction[T](transaction)
    var submission : string
    if encodedTxn.isEmptyOrWhitespace():

        let preHash = preHashMultiSigTxn()
        submission = "0x" & toHex(preHash, true) & toLowerAscii($serialize(transaction))

    else:

        submission = encodedTxn

    multiSignTransaction()

proc buildTransaction*[T : TransactionPayload](account : RefAptosAccount | RefMultiSigAccount, client : AptosClient, max_gas_amount = -1; gas_price = -1; txn_duration : int64 = -1) : Future[RawTransaction[T]] {.async.} =
    ## params :
    ## 
    ## account          -> account to build transaction for
    ## max_gas_amount   -> maximum amount of gas that can be sent for this transaction
    ## gas_price        -> price in octa unit per gas
    ## txn_duration     -> amount of time in seconds till transaction timeout 
    var 
        duration = txn_duration
        sequenceNumber : int
    if duration < 0:

        duration = 18000 ## set to 5 hours
    
    await account.refresh(client)
    when account is RefAptosAccount:
        
        sequenceNumber = account.sequence_number

    elif account is RefMultiSigAccount:

        sequenceNumber = account.next_sequence_number
   
    result = RawTransaction[T](
        chain_id : client.getNodeInfo().chain_id,
        sender : $account.address,
        sequence_number : $sequenceNumber,
        expiration_timestamp_secs : $(int64(epochTime()) + duration)
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

    let publicKey = cryptoutils.fromHex(pubkey)
    var ctx : SHA3
    sha3_init(ctx, SHA3_256)
    sha3_update(ctx, publicKey, len(publicKey))
    sha3_update(ctx, singleEd25519, 1)

    return "0x" & toHex(sha3_final(ctx), true)

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

        publicKeysConcat.add cryptoutils.fromHex(key)

    publicKeysConcat.add byte(threshold)

    var ctx : SHA3
    sha3_init(ctx, SHA3_256)
    sha3_update(ctx, publicKeysConcat, len(publicKeysConcat))
    sha3_update(ctx, multiEd25519, 1)

    return "0x" & toHex(sha3_final(ctx), true)

proc accountBalanceApt*(account : RefAptosAccount | RefMultiSigAccount, client : AptosClient) : Future[float] {.async.} =

    let resource = await client.getAccountResource($account.address, "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>")
    return parseInt(getStr(resource.data["coin"]["value"])).toApt()

proc accountExists*(client : AptosClient, address : string) : Future[bool] {.async.} =

    let resp = await executeModuleView[tuple[anon1 : string]](
        client,
        ViewRequest[tuple[anon1 : string]]( ## just give the field any random name
            function : "0x1::account::exists_at",
            type_arguments : @[],
            arguments : some((anon1 : address))
        )
    )
    return resp.fromJson(seq[bool])[0]

## initialization procs for type RefAptosAccount and RefMultiSigAccount
proc newAccount*(address, seed : string) : 
    RefAptosAccount =
    ## The seed is your 32 bytes | 64 character private key
    
    if not isValidSeed(seed):

        raise newException(InvalidSeed, fmt"seed {seed} is invalid")
    
    let keypair = getKeyPair(seed)
    return RefAptosAccount(
        address : newAddress(address),
        publicKey : keypair.pubkey,
        privateKey : keypair.prvkey,
        seed : seed 
    ) 

proc accountFromKey*(address, prikey : string) : RefAptosAccount =

    if not isPriKey(prikey):

        raise newException(InvalidSeed, fmt"private key {prikey} is invalid")

    let seed = getSeed(prikey)
    return newAccount(address, seed)

proc newMultiSigAccount*(accounts : seq[RefAptosAccount], address : string) : RefMultiSigAccount =
    
    return RefMultiSigAccount(
        address : newAddress(address),
        accounts : accounts
    )

proc createWallet*(client : AptosClient) : Future[RefAptosAccount] {.async.} =
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
    
        if not await client.accountExists(address):

            break
    
    result = newAccount(address, seed)

