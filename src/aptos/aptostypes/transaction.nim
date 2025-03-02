#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementation of aptos transactions

import std / [json, jsonutils]
from std / strutils import removePrefix, parseBiggestUInt
from std / typetraits import genericParams, get

import pkg / [bcs]

import authenticator / authenticator
import payload / payload
import ../movetypes/address

type

    RawTransaction*[T: TransactionPayload] = ref object of RootObj ## root of transaction object for sending transactions

        chain_id*: uint8
        sender*, sequence_number*, max_gas_amount*, gas_unit_price*,
            expiration_timestamp_secs*: string
        payload*: T

    SignedTransaction*[T: TransactionPayload] = ref object of RawTransaction[
            T] ## raw transaction with signature

        authenticator*: Authenticator

    SubmittedTransaction*[T: TransactionPayload] = ref object of SignedTransaction[
            T] ## transaction object returned from submitTransaction proc

        hash*: string

    MultiAgentRawTransaction*[T: TransactionPayload] = ref object of RawTransaction[
            T] ## raw transaction for signing with node

        secondary_signers*: seq[string]

## utils procs
proc toSignedTransaction*[T: TransactionPayload](txn: RawTransaction[T] |
        MultiAgentRawTransaction[T]): SignedTransaction[T] =

    result = SignedTransaction[T](
        chain_id: txn.chain_id,
        sender: txn.sender,
        sequence_number: txn.sequence_number,
        max_gas_amount: txn.max_gas_amount,
        gas_unit_price: txn.gas_unit_price,
        expiration_timestamp_secs: txn.expiration_timestamp_secs,
        payload: txn.payload
    )

proc toMultiAgentRawTransaction*[T: TransactionPayload](txn: RawTransaction[T] |
        SignedTransaction[T]): MultiAgentRawTransaction[T] =

    result = MultiAgentRawTransaction[T](
        chain_id: txn.chain_id,
        sender: txn.sender,
        sequence_number: txn.sequence_number,
        max_gas_amount: txn.max_gas_amount,
        gas_unit_price: txn.gas_unit_price,
        expiration_timestamp_secs: txn.expiration_timestamp_secs,
        payload: txn.payload
    )

## serialization procs
proc toBcsHook*(data: RawTransaction, output: var HexString) =

    let sender = fromString(data.sender)
    output.add $sender

    output.add serialize(parseBiggestUInt(
            data.sequence_number))

    toBcsHook(data.payload, output)

    output.add serialize(parseBiggestUInt(
            data.max_gas_amount))

    output.add serialize(parseBiggestUInt(
            data.gas_unit_price))

    output.add serialize(parseBiggestUInt(
            data.expiration_timestamp_secs))

    output.add serialize(data.chain_id)

proc fromBcsHook*(data: var HexString, output: var RawTransaction) =

    raise newException(NotImplemented, "RawTransaction bcs deserialization not implemented yet")
    #{.fatal : "RawTransaction bcs deSerialization not implemented yet".}

proc toBcsHook*[T: TransactionPayload](data: MultiAgentRawTransaction[
        T], output: var HexString) =

    output.add serialize(0'u8) ## a type of transaction variant serialization

    toBcsHook(RawTransaction[T](data), output)

    ## serialize secondary signers as a sequence of Address
    for val in serializeUleb128(uint32(len(data.secondary_signers))):

        output.add serialize(val)

    for signer in data.secondary_signers:

        toBcsHook(initAddress(signer), output)

proc fromBcsHook*(data: var HexString, output: var MultiAgentRawTransaction) =

    raise newException(NotImplemented, "MultiAgentRawTransaction bcs deserialization not implemented yet")

proc fromJsonHook*(v: var SignedTransaction, s: JsonNode) =

    v = SignedTransaction(
        sender: getStr(s["sender"]),
        sequence_number: getStr(s["sequence_number"]),
        max_gas_amount: getStr(s["max_gas_amount"]),
        gas_unit_price: getStr(s["gas_unit_price"]),
        expiration_timestamp_secs: getStr(s["expiration_timestamp_secs"]),
    )
    fromJsonHook(v.authenticator, s["signature"])

    when v.payload is EntryFunctionPayload:

        v.payload = jsonTo(s["payload"], EntryFunctionPayload)

    elif v.payload is ScriptPayload:

        v.payload = jsonTo(s["payload"], ScriptPayload)

    else:

        {.fatal: "unsupported payload type " & $(typeof(v.payload)).}

proc fromJsonHook*(v: var SubmittedTransaction, s: JsonNode) =

    var txn: SignedTransaction[genericParams(typeof(v)).get(0)]
    fromJsonHook(txn, s)
    v = cast[typeof(v)](txn)
    v.hash = getStr(s["hash"])

proc toJsonHook*(v: RawTransaction): JsonNode =

    var s = "{\"chain_id\":\"" & $v.chain_id & "\","
    s.add "\"sender\":\"" & v.sender & "\","
    s.add "\"sequence_number\":\"" & v.sequence_number & "\","
    s.add "\"max_gas_amount\":\"" & v.max_gas_amount & "\","
    s.add "\"gas_unit_price\":\"" & v.gas_unit_price & "\","
    s.add "\"expiration_timestamp_secs\":\"" & v.expiration_timestamp_secs & "\","
    s.add "\"payload\":" & $toJson(v.payload) & "}"

    return parseJson(s)

proc toJsonHook*(v: SignedTransaction): JsonNode =

    var s = "{\"chain_id\":\"" & $v.chain_id & "\","
    s.add "\"sender\":\"" & v.sender & "\","
    s.add "\"sequence_number\":\"" & v.sequence_number & "\","
    s.add "\"max_gas_amount\":\"" & v.max_gas_amount & "\","
    s.add "\"gas_unit_price\":\"" & v.gas_unit_price & "\","
    s.add "\"expiration_timestamp_secs\":\"" & v.expiration_timestamp_secs & "\","
    s.add "\"payload\":" & $toJson(v.payload) & ","
    s.add "\"signature\":" & $toJsonHook(v.authenticator) & "}"

    return parseJson(s)

proc toJsonHook*(v: SubmittedTransaction): JsonNode =

    var s = "{\"hash\":\"" & v.hash & "\","
    s.add "\"sender\":\"" & v.sender & "\","
    s.add "\"sequence_number\":\"" & v.sequence_number & "\","
    s.add "\"max_gas_amount\":\"" & v.max_gas_amount & "\","
    s.add "\"gas_unit_price\":\"" & v.gas_unit_price & "\","
    s.add "\"expiration_timestamp_secs\":\"" & v.expiration_timestamp_secs & "\","
    s.add "\"payload\":" & $toJson(v.payload) & ","
    s.add "\"signature\":" & $toJsonHook(v.authenticator) & "}"

    return parseJson(s)

proc toJsonHook*(v: MultiAgentRawTransaction): JsonNode =

    var s = "{\"chain_id\":\"" & $v.chain_id & "\","
    s.add "\"sender\":\"" & v.sender & "\","
    s.add "\"sequence_number\":\"" & v.sequence_number & "\","
    s.add "\"max_gas_amount\":\"" & v.max_gas_amount & "\","
    s.add "\"gas_unit_price\":\"" & v.gas_unit_price & "\","
    s.add "\"expiration_timestamp_secs\":\"" & v.expiration_timestamp_secs & "\","
    s.add "\"payload\":" & $toJson(v.payload) & ","
    s.add "\"secondary_signers\":" & $toJson(v.secondary_signers) & "}"

    return parseJson(s)

proc `$`*(data: RawTransaction): string = $toJson(data)

proc `$`*(data: SignedTransaction): string = $toJson(data)

proc `$`*(data: MultiAgentRawTransaction): string = $toJson(data)

proc `$`*(data: SubmittedTransaction): string = $toJson(data)


