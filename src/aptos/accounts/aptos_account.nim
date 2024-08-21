
#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## This module implements procs to work with the RefAptosAccount type

when defined(js):

    {.fatal: "js backend is not implemented for aptos_account module".}

## std imports
import std / [asyncdispatch]
from std / strformat import fmt
from std / strutils import toLowerAscii, isEmptyOrWhitespace, toHex

## nimble imports
import pkg / [sha3, bcs]
import pkg / nimcrypto / utils as cryptoutils

## project imports
import ./utils
import ../ed25519/ed25519
import ../api/[aptosclient]
import ../aptostypes/[transaction]
import ../aptostypes/authenticator/[authenticator]
from ../aptostypes/payload/payload import TransactionPayload

when defined(debug):

    import std / [logging]

#const
    #guidObjectAddress : byte = 253
    #seedObjectAddress : byte = 254
    #resourceAccountAddress : byte = 255

## Aptos Account signing procs
proc signMsg*(account: RefAptosAccount, msg: string): string = signHex(
        account.getPrivateKey()[2..^1], msg)

proc verifySignature*(account: RefAptosAccount, signature,
        msg: string): bool = verifyHex(account.getPublicKey()[2..^1], signature, msg)

## Aptos Account transaction procs
template signTransaction() =

    when defined(debug):

        debug submission ## using this to debug bcs encoding of transaction

    let signature = "0x" & signMsg(account, submission)
    assert verifySignature(account, signature, submission),
            fmt"cannot verify signature for 0x" & account.getPublicKey()
    result.authenticator = initAuthenticator(
        SingleEd25519,
        initSingleEd25519Authenticator(
            initSinglePubKey(fromString(account.getPublicKey())),
            initSingleSignature(fromString(signature))
        )
    )

proc signTransaction*[T: TransactionPayload](account: RefAptosAccount,
        client: AptosClient, transaction: RawTransaction[T],
        encodedTxn: string = ""): Future[SignedTransaction[T]] {.async.} =
    ## signs transaction by encoding transaction to bcs on the node
    ## then signing it locally

    result = toSignedTransaction[T](transaction)
    var submission: string
    if encodedTxn.isEmptyOrWhitespace():

        submission = await client.encodeSubmission(transaction)

    else:

        submission = encodedTxn

    signTransaction()

template preHashRawTxn(): untyped =

    var ctx: SHA3
    let bcsTxn = "APTOS::RawTransaction"
    sha3_init(ctx, SHA3_256)
    sha3_update(ctx, bcsTxn, len(bcsTxn))

    let hash = sha3_final(ctx)
    when defined(debug):

        debug(hash)

    hash

proc signTransaction*[T: TransactionPayload](account: RefAptosAccount,
        transaction: RawTransaction[T],
        encodedTxn: string = ""): SignedTransaction[T] =
    ## signs transaction by encoding transaction to bcs locally
    ## then signing it locally

    result = toSignedTransaction[T](transaction)
    var submission: string
    if encodedTxn.isEmptyOrWhitespace():

        let preHash = preHashRawTxn()
        submission = "0x" & toHex(preHash, true) & toLowerAscii($serialize(transaction))

    else:

        submission = encodedTxn

    signTransaction()

## Aptos Account util procs
proc getAddressFromKey*(pubkey: string): string =
    ## gets address from public key
    ## for single Ed25519 accounts

    if not isValidSeed(pubkey):

        raise newException(InvalidSeed, fmt"public key {pubkey} is invalid")

    let publicKey = cryptoutils.fromHex(pubkey)
    var ctx: SHA3
    sha3_init(ctx, SHA3_256)
    sha3_update(ctx, publicKey, len(publicKey))
    sha3_update(ctx, uint8(SINGLE_ED25519_SIG_ENUM), 1)

    return "0x" & toHex(sha3_final(ctx), true)

proc accountFromKey*(address, prikey: string): RefAptosAccount =

    if not isPriKey(prikey):

        raise newException(InvalidSeed, fmt"private key {prikey} is invalid")

    let seed = getSeed(prikey)
    return newAccount(address, seed)

proc createAccount*(client: AptosClient): Future[RefAptosAccount] {.async.} =
    ## This proc only creates a new random keypair and seed hash
    ## and it initializes a new RefAptosAccount object
    ## it does not how ever register the new wallet with the
    ## aptos blockchain.
    ## To do this use the faucet node to get APT into the wallet
    ## or call the aptos move function `0x1::aptos_account::create_account`.
    ## or call the registerAccount proc in the aptos.nim file
    ## NOTE :: registeration of account is chain specific. Which means registeration on
    ## devnet will not show on mainnet and vice versa

    var seed, address: string
    while true:

        seed = "0x" & toHex(@(randomSeed()), true)
        let keyPair = getKeyPair(seed)
        address = getAddressFromKey(keyPair.pubkey)

        if not await client.accountExists(address):

            break

    result = newAccount(address, seed)
