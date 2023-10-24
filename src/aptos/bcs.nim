import std / [json, tables]
import pkg / [bcs]
from std / strutils import toHex, parseBiggestUInt

import datatype / [payload, transaction]
from datatype / move import bcsVal
{.warning : "invalid bcs implementation. Will be updated soon".}

type

    NotImplementedError = object of CatchableError

template removePrefix(data : string) : untyped =
    
    var resultImpl = data
    if len(data) > 2:

        if data[0..1] == "0x":

            resultImpl = data[2..^1]

    resultImpl

proc serializeJsonNode(data : JsonNode) : string =

    case data.kind

    of JString:

        return serializeStr(data.str)

    of JInt:

        serialize[int64](data.num, result)
        return result

    of JFloat:

        raise newException(ValueError, "type float is not supported by bcs")

    of JBool:

        return serializeBool(data.bval)

    of JNull:

        raise newException(NotImplementedError, "nil type not implemented for bcs serialization")

    of JObject:
        
        for key, val in data.fields:

            result.add serializeJsonNode(val)

        return result

    of JArray:

        for item in data.elems:

            result.add serializeJsonNode(item) ## treat as fixed lenght array

        return result

proc serialize(payload : Payload) : string =

    case payload.`type`

    of EntryFunction, ScriptPayload:
        
        var args : seq[JsonNode]
        for each in payload.entry_arguments:

            args.add each.bcsVal()

        if payload.`type` == EntryFunction:

            result = serializeStr(payload.function) & serializeArray(payload.entry_type_arguments)

        elif payload.`type` == ScriptPayload:
            
            var codeBcs : string
            serialize(payload.code, codeBcs)

            result = codeBcs & serializeArray(payload.script_type_arguments)
        
        result.add toHex(len(args))
        for arg in args:

            result.add serializeJsonNode(arg)

    else:

        var serOutput : string
        serialize(payload, serOutput)

        result = serOutput

method serialize*(transaction : RawTransaction) : string {.base.} =
    
    if transaction.isNil():

        raise newException(NilAccessDefect, "transaction is nil")
    
    #serialize(result, int16(transaction.chain_id))
    result.add removePrefix(transaction.sender)
    serialize(parseBiggestUInt(transaction.sequence_number), result)
    serialize(parseBiggestUInt(transaction.max_gas_amount), result)
    serialize(parseBiggestUInt(transaction.gas_unit_price), result)
    serialize(parseBiggestUInt(transaction.expiration_timestamp_secs), result)
    result.add serialize(transaction.payload)

