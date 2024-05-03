#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementation of aptos transactions

import std / [json]
from std / strutils import removePrefix, parseBiggestUInt

import pkg / [jsony, bcs]

import signature, payload
import ../movetypes/address

type

    RawTransaction*[T : TransactionPayload] = ref object of RootObj ## root of transaction object for sending transactions
        
        chain_id* : uint8
        sender*, sequence_number*, max_gas_amount*, gas_unit_price*, expiration_timestamp_secs* : string
        payload* : T
    
    SignTransaction*[T : TransactionPayload] = ref object of RawTransaction[T] ## raw transaction with signature

        signature* : Signature

    SubmittedTransaction*[T : TransactionPayload] = ref object of SignTransaction[T] ## transaction object returned from submitTransaction proc

        hash* : string

    MultiAgentRawTransaction*[T : TransactionPayload] = ref object of RawTransaction[T] ## raw transaction for signing with node

        secondary_signers* : seq[string]

proc serialize*(transaction : RawTransaction) : HexString =
    
    if transaction.isNil():

        raise newException(NilAccessDefect, "transaction is nil")

    let sender = fromString(transaction.sender)
    result.add $sender

    result.add bcs.serialize[uint64](parseBiggestUInt(transaction.sequence_number))
    
    var payloadHex : HexString
    when transaction.payload is EntryFunctionPayload: 
        
        payloadHex = serializeEntryFunction[EntryFunctionPayload](transaction.payload)

    elif transaction.payload is ScriptPayload:

        payloadHex = serializeScriptPayload[ScriptPayload](transactions.payload)

    result.add payloadHex

    result.add bcs.serialize[uint64](parseBiggestUInt(transaction.max_gas_amount))

    result.add bcs.serialize[uint64](parseBiggestUInt(transaction.gas_unit_price))

    result.add bcs.serialize[uint64](parseBiggestUInt(transaction.expiration_timestamp_secs))

    result.add bcs.serialize[uint8](transaction.chain_id)

proc deSerialize*(data : var HexString) : RawTransaction =

    discard

proc serialize*[T : TransactionPayload](transaction : MultiAgentRawTransaction[T]) : HexString =
    
    if transaction.isNil():

        raise newException(NilAccessDefect, "transaction is nil")

    result.add bcs.serialize[uint8](0'u8) ## a type of transaction variant serialization

    let rawTxn = RawTransaction[T](transaction)
    let rawEncode = serialize(rawTxn)
    #echo "raw : ", rawEncode, "\n"
    result.add rawEncode
    
    ## serialize secondary signers as a sequence of Address
    for val in serializeUleb128(uint32(len(transaction.secondary_signers))):

        result.add bcs.serialize[uint8](val)

    for signer in transaction.secondary_signers:

        result.add address.serialize(newAddress(signer))

proc parseHook*(s : string, i : var int, v : var SubmittedTransaction) =

    var jsonTransaction : JsonNode
    parseHook(s, i, jsonTransaction)

    v = SubmittedTransaction(
        hash : getStr(jsonTransaction["hash"]),
        sender : getStr(jsonTransaction["sender"]),
        sequence_number : getStr(jsonTransaction["sequence_number"]),
        max_gas_amount : getStr(jsonTransaction["max_gas_amount"]),
        gas_unit_price : getStr(jsonTransaction["gas_unit_price"]),
        expiration_timestamp_secs : getStr(jsonTransaction["expiration_timestamp_secs"]),
        signature : ($jsonTransaction["signature"]).fromJson(Signature),
    )

    when v.payload is EntryFunctionPayload:
        
        v.payload = ($jsonTransaction["payload"]).fromJson(EntryFunctionPayload)    

    elif v.payload is ScriptPayload:

        v.payload = ($jsonTransaction["payload"]).fromJson(ScriptPayload)

    else:

        raise newException(ValueError, "unsupported payload type " & payloadType)

proc dumpHook*(s : var string, v : RawTransaction) =
    
    s.add "{\"chain_id\":\"" & $v.chain_id & "\","
    s.add "\"sender\":\"" & v.sender & "\","
    s.add "\"sequence_number\":\"" & v.sequence_number & "\","
    s.add "\"max_gas_amount\":\"" & v.max_gas_amount & "\","
    s.add "\"gas_unit_price\":\"" & v.gas_unit_price & "\","
    s.add "\"expiration_timestamp_secs\":\"" & v.expiration_timestamp_secs & "\","
    s.add "\"payload\":" & jsony.toJson(v.payload) & "}"

proc dumpHook*(s : var string, v : SignTransaction) =
    
    s.add "{\"chain_id\":\"" & $v.chain_id & "\","
    s.add "\"sender\":\"" & v.sender & "\","
    s.add "\"sequence_number\":\"" & v.sequence_number & "\","
    s.add "\"max_gas_amount\":\"" & v.max_gas_amount & "\","
    s.add "\"gas_unit_price\":\"" & v.gas_unit_price & "\","
    s.add "\"expiration_timestamp_secs\":\"" & v.expiration_timestamp_secs & "\","
    s.add "\"payload\":" & jsony.toJson(v.payload) & ","
    s.add "\"signature\":" & jsony.toJson(v.signature) & "}"

proc dumpHook*(s : var string, v : SubmittedTransaction) =
    
    s.add "{\"hash\":\"" & v.hash & "\","
    s.add "\"sender\":\"" & v.sender & "\","
    s.add "\"sequence_number\":\"" & v.sequence_number & "\","
    s.add "\"max_gas_amount\":\"" & v.max_gas_amount & "\","
    s.add "\"gas_unit_price\":\"" & v.gas_unit_price & "\","
    s.add "\"expiration_timestamp_secs\":\"" & v.expiration_timestamp_secs & "\","
    s.add "\"payload\":" & jsony.toJson(v.payload) & ","
    s.add "\"signature\":" & jsony.toJson(v.signature) & "}"

proc dumpHook*(s : var string, v : MultiAgentRawTransaction) =
    
    s.add "{\"chain_id\":\"" & $v.chain_id & "\","
    s.add "\"sender\":\"" & v.sender & "\","
    s.add "\"sequence_number\":\"" & v.sequence_number & "\","
    s.add "\"max_gas_amount\":\"" & v.max_gas_amount & "\","
    s.add "\"gas_unit_price\":\"" & v.gas_unit_price & "\","
    s.add "\"expiration_timestamp_secs\":\"" & v.expiration_timestamp_secs & "\","
    s.add "\"payload\":" & jsony.toJson(v.payload) & "," 
    s.add "\"secondary_signers\":" & jsony.toJson(v.secondary_signers) & "}"

proc `$`*(data : RawTransaction) : string = jsony.toJson(data)

proc `$`*(data : SignTransaction) : string = jsony.toJson(data)

proc `$`*(data : MultiAgentRawTransaction) : string = jsony.toJson(data)

proc `$`*(data : SubmittedTransaction) : string = jsony.toJson(data)

proc toSignTransaction*[T : TransactionPayload](txn : RawTransaction[T] | MultiAgentRawTransaction[T]) : SignTransaction[T] =

    result = SignTransaction[T](
        chain_id : txn.chain_id,
        sender : txn.sender, 
        sequence_number : txn.sequence_number, 
        max_gas_amount : txn.max_gas_amount, 
        gas_unit_price : txn.gas_unit_price, 
        expiration_timestamp_secs : txn.expiration_timestamp_secs,
        payload : txn.payload
    )

proc toMultiAgentRawTransaction*[T : TransactionPayload](txn : RawTransaction[T] | SignTransaction[T]) : MultiAgentRawTransaction[T] =

    result = MultiAgentRawTransaction[T](
        chain_id : txn.chain_id,
        sender : txn.sender, 
        sequence_number : txn.sequence_number, 
        max_gas_amount : txn.max_gas_amount, 
        gas_unit_price : txn.gas_unit_price, 
        expiration_timestamp_secs : txn.expiration_timestamp_secs,
        payload : txn.payload
    )

