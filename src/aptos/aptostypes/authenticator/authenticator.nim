#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementation of aptos authenticator types
{.experimental: "codeReOrdering".}

## std imports
import std / [jsonutils, json]
from std / strformat import fmt

## third party imports
import pkg / [bcs]

## project imports
import signature, publickey
import ../../movetypes/[address]
import ../../errors

export signature, publickey

type

    AuthenticatorType* {.pure.} = enum

        SingleEd25519 = "ed25519_signature"
        MultiEd25519 = "multi_ed25519_signature"
        MultiAgentEd25519 = "multi_agent_signature"

    Authenticator* = object

        case `type`*: AuthenticatorType
        of SingleEd25519:

            single_auth: SingleEd25519Authenticator

        of MultiEd25519:

            multi_auth: MultiEd25519Authenticator

        of MultiAgentEd25519:

            multi_agent_auth: MultiAgentEd25519Authenticator

    SingleEd25519Authenticator = object

        public_key*: SinglePubKey
        signature*: SingleEd25519Signature

    MultiEd25519Authenticator = object

        public_keys*: MultiPubKey
        signatures*: MultiEd25519Signature

    MultiAgentEd25519Authenticator = object

        secondary_signer_addresses*: seq[Address]
        sender*: ref Authenticator
        secondary_signers*: seq[Authenticator]

proc initAuthenticator*(authType: AuthenticatorType,
        data: SingleEd25519Authenticator | MultiEd25519Authenticator |
        MultiAgentEd25519Authenticator): Authenticator =

    when data is SingleEd25519Authenticator:

        result = Authenticator(`type`: authType)
        result.single_auth = data

    elif data is MultiEd25519Authenticator:

        result = Authenticator(`type`: authType)
        result.multi_auth = data

    elif data is MultiAgentEd25519Authenticator:

        result = Authenticator(`type`: authType)
        result.multi_agent_auth = data

proc initSingleEd25519Authenticator*(public_key: SinglePubKey,
        signature: SingleEd25519Signature): SingleEd25519Authenticator =

    return SingleEd25519Authenticator(
        public_key: public_key,
        signature: signature
    )

proc initMultiEd25519Authenticator*(public_keys: MultiPubKey,
        signatures: MultiEd25519Signature): MultiEd25519Authenticator =

    return MultiEd25519Authenticator(
        public_keys: public_keys,
        signatures: signatures
    )

proc initMultiAgentEd25519Authenticator*(secondary_signer_addresses: seq[
        Address], sender: Authenticator, secondary_signers: seq[
        Authenticator]): MultiAgentEd25519Authenticator =

    result.secondary_signer_addresses = secondary_signer_addresses

    result.sender = new Authenticator
    result.sender[] = sender
    result.secondary_signers = secondary_signers

template getAuthenticator(data: Authenticator, code: untyped): untyped =

    case data.`type`

    of SingleEd25519:

        let auth {.inject.} = data.single_auth
        code

    of MultiEd25519:

        let auth {.inject.} = data.multi_auth
        code

    of MultiAgentEd25519:

        let auth {.inject.} = data.multi_agent_auth
        code

    #[else:

        raise newException(JsonKindError, "authenticator type " & $data.`type` & " is not supported")]#

## serialization procs
template fromJsonHook(v: var SingleEd25519Authenticator, s: JsonNode) =

    let authType = getStr(s["type"])
    if authType != $SingleEd25519:

        raise newException(JsonKindError,
                fmt"authenticator type is {authType} expected {SingleEd25519}")

    v = SingleEd25519Authenticator(
        public_key: initSinglePubKey(fromString(getStr(s["public_key"]))),
        signature: initSingleSignature(fromString(getStr(s["signature"])))
    )

template fromJsonHook(v: var MultiEd25519Authenticator, s: JsonNode) =

    let authType = getStr(s["type"])
    if authType != $MultiEd25519:

        raise newException(JsonKindError,
                fmt"authenticator type is {authType} expected {MultiEd25519}")

    var publicKeys: seq[SinglePubKey]
    for key in s["public_keys"]:

        public_keys.add initSinglePubKey(getStr(key))

    var signatures: seq[SingleEd25519Signature]
    for sig in s["signatures"]:

        signatures.add initSingleSignature(getStr(sig))

    v = MultiEd25519Authenticator(
        public_keys: initMultiPubKey(publicKeys, getInt(s["threshold"])),
        signatures: initMultiSignature(signatures, fromString(getStr(s["bitmap"])))
    )

template fromJsonHook(v: var MultiAgentEd25519Authenticator,
        s: JsonNode): untyped =

    let authType = getStr(s["type"])
    if authType != $MultiAgentEd25519:

        raise newException(JsonKindError,
                fmt"authenticator type is {authType} expected {MultiAgentEd25519}")

    var sec_signer_address = newSeq[Address](len(s[
            "secondary_signer_addresses"]))
    for pos in 0..<len(sec_signer_address):

        fromJsonHook(sec_signer_address[pos], s["secondary_signer_addresses"][pos])

    var sec_signers: seq[Authenticator]
    for sec_signer in s["secondary_signers"]:

        var auth: Authenticator
        fromJsonHook(auth, sec_signer)
        sec_signers.add auth

    v.secondary_signer_addresses = sec_signer_address
    v.secondary_signers = sec_signers

    v.sender = new Authenticator
    fromJsonHook(v.sender[], s["sender"])

proc fromJsonHook*(v: var Authenticator, s: JsonNode) =

    let authType = getStr(s["type"])
    case authType

    of $SingleEd25519:

        v = Authenticator(`type`: SingleEd25519)
        #v.`type` = SingleEd25519
        fromJsonHook(v.single_auth, s)

    of $MultiEd25519:

        v = Authenticator(`type`: MultiEd25519)
        #v.`type` = MultiEd25519
        fromJsonHook(v.multi_auth, s)

    of $MultiAgentEd25519:

        v = Authenticator(`type`: MultiAgentEd25519)
        #v.`type` = MultiAgentEd25519
        fromJsonHook(v.multi_agent_auth, s)

    else:

        raise newException(JsonKindError, "authenticator type " & authType & " is not supported")

template toJsonHook(v: SingleEd25519Authenticator): untyped =

    toJson((
        public_key: $v.public_key,
        signature: $v.signature
    ))

template toJsonHook(v: MultiEd25519Authenticator): untyped =

    var public_keys: seq[string]
    for key in v.public_keys.getKeys():

        public_keys.add $key

    var signatures: seq[string]
    for sig in v.signatures.getSignatures():

        signatures.add $sig

    toJson((
        public_keys: public_keys,
        signatures: signatures,
        bitmap: $v.signatures.getBitmap(),
        threshold: v.public_keys.getThreshold()
    ))

template toJsonHook(v: MultiAgentEd25519Authenticator): untyped =

    var jsonResult = toJson((
        secondary_signer_addresses: toJson(v.secondary_signer_addresses)
    ))
    jsonResult["sender"] = toJsonHook(v.sender[])
    jsonResult["secondary_signers"] = newJArray()
    for secondary_signer in v.secondary_signers:

        jsonResult["secondary_signers"].add toJsonHook(secondary_signer)

    jsonResult

proc toJsonHook*(v: Authenticator): JsonNode =

    getAuthenticator v:

        when auth is SingleEd25519Authenticator:

            result = toJsonHook(auth)
            result["type"] = %($SingleEd25519)

        elif auth is MultiEd25519Authenticator:

            result = toJsonHook(auth)
            result["type"] = %($MultiEd25519)

        elif auth is MultiAgentEd25519Authenticator:

            result = toJsonHook(auth)
            result["type"] = %($MultiAgentEd25519)

proc toBcsHook*(data: SingleEd25519Authenticator, output: var HexString) =

    publickey.toBcsHook(data.public_key, output)
    signature.toBcsHook(data.signature, output)

proc toBcsHook*(data: MultiEd25519Authenticator, output: var HexString) =

    toBcsHook(data.public_keys, output)
    toBcsHook(data.signatures, output)

template toBcsHook(data: MultiAgentEd25519Authenticator,
        output: var HexString) =

    toBcsHook(data.sender[], output)

    ## signer addresses
    for val in serializeUleb128(uint32(len(data.secondary_signer_addresses))):

        output.add serialize(val)

    for address in data.secondary_signer_addresses:

        toBcsHook(address, output)

    ## signer authenticators
    for val in serializeUleb128(uint32(len(data.secondary_signers))):

        output.add serialize(val)

    for signer in data.secondary_signers:

        toBcsHook(signer, output)

proc toBcsHook*(data: Authenticator, output: var HexString) =

    for val in serializeUleb128(uint32(ord(data.`type`))):

        output.add serialize(val)

    getAuthenticator data:

        toBcsHook(auth, output)

proc fromBcsHook*(data: var HexString,
        output: var SingleEd25519Authenticator) =

    publickey.fromBcsHook(data, output.publickey)
    signature.fromBcsHook(data, output.signature)

proc fromBcsHook*(data: var HexString, output: var MultiEd25519Authenticator) =

    ## deSerialization of MultiEd25519Signature is problematic
    ## as such this proc cannot be implemented not
    ## TODO :: improve both implementations
    raise newException(NotImplemented, "MultiEd25519Authenticator bcs deserialization not implemented yet")
    #{.fatal: "MultiEd25519Authenticator deSerialization is not implemented yet".}

template fromBcsHook*(data: var HexString,
        output: var MultiAgentEd25519Authenticator) =

    fromBcsHook(data, output.sender[])

    ## signer addresses
    let signerAddrsLen = deSerializeUleb128(data)
    output.secondary_signer_addresses.newSeq(signerAddrsLen)
    for pos in 0..<signerAddrsLen:

        fromBcsHook(data, output.secondary_signer_addresses[pos])

    ## signer auths
    let signerAuthLen = deSerializeUleb128(data)
    output.secondary_signers.newSeq(signerAuthLen)
    for pos in 0..<signerAuthLen:

        fromBcsHook(data, output.secondary_signers[pos])

proc fromBcsHook*(data: var HexString, output: var Authenticator) =

    let variant = deSerializeUleb128(data)
    case AuthenticatorType(variant)

    of SingleEd25519:

        fromBcsHook(data, output.single_auth)

    of MultiEd25519:

        fromBcsHook(data, output.multi_auth)

    of MultiAgentEd25519:

        fromBcsHook(data, output.multi_agent_auth)

