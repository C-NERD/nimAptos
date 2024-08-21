## 
## This module implements procs to work with the RefMultiSigAccount type
## and procs to call MultiSig Account move functions

when defined(js):

    {.fatal: "js backend is not implemented for multisig_account module".}

import std / [asyncdispatch, json, jsonutils]
from std / options import Option, some, none
from std / tables import Table, toTable, initTable, `[]=`
from std / strutils import toLowerAscii, isEmptyOrWhitespace, toHex
from std / strformat import fmt

## nimble imports
import pkg / [sha3, bcs]
import pkg / nimcrypto / utils as cryptoutils

## project imports
import ./utils
import ../aptostypes/transaction
import ../movetypes/[address, arguments]
import ../api/[aptosclient, nodetypes]
import ../aptostypes/authenticator/[authenticator, signature]
from ./aptos_account import signMsg, verifySignature
from ../aptostypes/payload/payload import TransactionPayload, EntryFunctionPayload
from ../aptostypes/payload/moduleid import newModuleId

when defined(debug):

    import std / [logging]

type

    Vote* {.pure.} = enum

        Approve, Reject ## approve should be sent as true and reject as false

    MultiSigTransaction = object

        payload*: Option[HexString]
        payload_hash*: Option[HexString]
        votes*: Table[Address, Vote]
        creator*: Address
        creation_time_secs*: uint64

## MultiSigTransaction helpers
    #[proc initMultiSigTransaction() : MultiSigTransaction =

    discard]#

proc fromJsonHook*(v: var MultiSigTransaction, s: JsonNode) =

    var
        payload, payload_hash: Option[HexString]
        votes = initTable[Address, Vote]()
    if s["payload"].kind == JNull:

        payload = none[HexString]()

    else:

        payload = some(fromString(getStr(s["payload"])))

    if s["payload_hash"].kind == JNull:

        payload_hash = none[HexString]()

    else:

        payload = some(fromString(getStr(s["payload_hash"])))

    for key, val in s["votes"]:

        let voteBool = getBool(val)
        var vote: Vote
        if voteBool:

            vote = Approve

        else:

            vote = Reject

        votes[initAddress(key)] = vote

    v = MultiSigTransaction(
        payload: payload,
        payload_hash: payload_hash,
        votes: votes,
        creator: initAddress(getStr(s["creator"])),
        creation_time_secs: uint64(getInt(s["creation_time_secs"]))
    )

proc fromJsonHook*(v: var seq[MultiSigTransaction], s: JsonNode) =

    for txn in s:

        var transaction: MultiSigTransaction
        fromJsonHook(transaction, txn)
        v.add transaction

## constants
const MAX_PENDING_TRANSACTIONS = 20

## MultiSig signing based procs
proc signMsg*(account: RefMultiSigAccount, msg: string): seq[tuple[
        ownerpos: int, signature: string]] =

    for pos in 0..<len(account.accounts):

        result.add (pos, signMsg(account.accounts[pos], msg))

proc verifySignature*(account: RefMultiSigAccount, signatures: seq[tuple[
        ownerpos: int, signature: string]], msg: string): bool =

    for sig in signatures:

        if not verifySignature(account.accounts[sig.ownerpos], sig.signature, msg):

            return false

    return true

## MultiSig account transaction procs
template multiSignTransaction() =

    when defined(debug):

        debug submission

    var
        publicKeys: seq[HexString]
        signatures: seq[HexString]
        bitPos: seq[int]

    let acctLen = len(account.accounts)
    assert acctLen < 32, "bitmap value exceeds maximum value"

    for pos in 0..<acctLen:

        let
            pubkey = fromString(account.accounts[pos].getPublicKey()[2..^1])
            signature = fromString(signMsg(account.accounts[pos], submission))

        publicKeys.add pubkey
        signatures.add signature

        assert verifySignature(account.accounts[pos], $signature, submission),
                "cannot verify signature for " & $pubkey
        bitPos.add pos

    result.authenticator = initAuthenticator(
        MultiEd25519,
        initMultiEd25519Authenticator(
            initMultiPubKey(publicKeys, account.num_signatures_required),
            initMultiSignature(signatures, bitPos)
        )
    )

proc multiSignTransaction*[T: TransactionPayload](account: RefMultiSigAccount,
        client: AptosClient, transaction: RawTransaction[T],
        encodedTxn: string = ""): Future[SignedTransaction[T]] {.async.} =

    result = toSignedTransaction[T](transaction)
    var submission: string
    if encodedTxn.isEmptyOrWhitespace():

        submission = await client.encodeSubmission(transaction)

    else:

        submission = encodedTxn

    multiSignTransaction()

template preHashMultiSigTxn(): untyped =

    var ctx: SHA3
    let bcsTxn = "APTOS::RawTransaction"
    sha3_init(ctx, SHA3_256)
    sha3_update(ctx, bcsTxn, len(bcsTxn))

    let hash = sha3_final(ctx)
    when defined(debug):

        debug(hash)

    hash

proc multiSignTransaction*[T: TransactionPayload](account: RefMultiSigAccount,
        transaction: RawTransaction[T],
        encodedTxn: string = ""): SignedTransaction[T] =

    result = toSignedTransaction[T](transaction)
    var submission: string
    if encodedTxn.isEmptyOrWhitespace():

        let preHash = preHashMultiSigTxn()
        submission = "0x" & toHex(preHash, true) & toLowerAscii($serialize(transaction))

    else:

        submission = encodedTxn

    multiSignTransaction()

## MultiSig utils procs
proc getAddressFromKeys*(keys: seq[string], threshold: range[1..32]): string =
    ## gets address from public keys
    ## for multi sig accounts

    let keyNum = len(keys)
    if keyNum < 2 or keyNum > 32:

        raise newException(IndexDefect, "len of keys sequence should be >= 2 and <= 32")

    for key in keys:

        if not isValidSeed(key):

            raise newException(InvalidSeed, fmt"public key {key} is invalid")

    var publicKeysConcat: seq[byte]
    for key in keys:

        publicKeysConcat.add cryptoutils.fromHex(key)

    publicKeysConcat.add byte(threshold)

    var ctx: SHA3
    sha3_init(ctx, SHA3_256)
    sha3_update(ctx, publicKeysConcat, len(publicKeysConcat))
    sha3_update(ctx, uint8(MULTI_ED25519_SIG_ENUM), 1)

    return "0x" & toLowerAscii(toHex(sha3_final(ctx), true))

proc createMultiSigAccount*(client: AptosClient, owners: seq[RefAptosAccount],
        threshold: uint64): Future[RefMultiSigAccount] {.async.} =

    var
        address: string
        keys: seq[string]

    for owner in owners:

        keys.add owner.getPublicKey()[2..^1]

    while true:

        address = getAddressFromKeys(keys, threshold)
        if not await client.accountExists(address):

            break

    result = newMultiSigAccount(owners, address)
    result.num_signatures_required = threshold
    result.last_executed_sequence_number = 0
    result.next_sequence_number = 1

## Helper procs for move MultiSig
template isTxnCapFull(account: RefMultiSigAccount): untyped =

    var full: bool = false
    if (account.next_sequence_number - account.last_executed_sequence_number) < MAX_PENDING_TRANSACTIONS:

        full = true

    full

#[template canExecute(sequenceNumber : uint64) : untyped =

    let cond : bool = false
    cond

template canReject(sequenceNumber : uint64) : untyped =

    let cond : bool = false
    cond]#

## MultiSig move procs
proc createMultiSigTransaction*(account: RefMultiSigAccount,
        payload: HexString): EntryFunctionPayload =

    assert isTxnCapFull(account), "MultiSig transaction capacity is full, try approving or rejecting pending transactions first"
    return EntryFunctionPayload(
        moduleid: newModuleId("0x1::multisig_account"),
        function: "create_transaction",
        type_arguments: @[],
        arguments: @[eArg account.address, eArg payload]
    )

proc voteOnTransaction*(account: RefMultiSigAccount, sequenceNumber: uint64,
        vote: Vote): EntryFunctionPayload =

    var voteBool: bool
    case vote

    of Approve:

        #assert canExecute(sequenceNumber), fmt"Terminating voting for txn {sequenceNumber}, cannot execute transaction"
        voteBool = true

    of Reject:

        #assert canReject(sequenceNumber), fmt"Terminating voting for txn {sequenceNumber}, cannot reject transaction"
        voteBool = false

    return EntryFunctionPayload(
        moduleid: newModuleId("0x1::multisig_account"),
        function: "vote_transaction",
        type_arguments: @[],
        arguments: @[eArg account.address, eArg sequenceNumber, eArg voteBool]
    )

proc removeRejectedTransactions*(account: RefMultiSigAccount,
        finalSequenceNumber: uint64): EntryFunctionPayload =
    ## removes txns if they have enough rejection votes

    return EntryFunctionPayload(
        moduleid: newModuleId("0x1::multisig_account"),
        function: "execute_rejected_transactions",
        type_arguments: @[],
        arguments: @[eArg account.address, eArg finalSequenceNumber]
    )

proc getPendingTransactions*(account: RefMultiSigAccount,
        client: AptosClient): Future[seq[MultiSigTransaction]] {.async.} =

    let resp = await executeModuleView[tuple[anon1: string]](
        client,
        ViewRequest[tuple[anon1: string]]( ## just give the field any random name
        function: "0x1::multisig_account::get_pending_transactions",
        type_arguments: @[],
        arguments: some((anon1: $account.address))
    )
    )
    return jsonTo(parseJson(resp), seq[MultiSigTransaction])

#[iterator getExecutedTransactions*() : MultiSigTransaction = ## use movescript for this

    discard

iterator getAllTransactions*() : MultiSigTransaction =

    discard]#

