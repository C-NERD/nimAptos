import std / json
from std / strutils import toHex
import pkg / bcs
from datatype import RawTransaction, Payload, PayloadType, InvalidTransaction

{.warning : "invalid bcs implementation. Will be updated soon".}

proc encodePayload(payload : Payload) : string =

    case payload.`type`

    of EntryFunction, ScriptPayload:
        
        var args : seq[JsonNode]
        if payload.`type` == EntryFunction:

            result = serializeStr(payload.function) & serializeArray(payload.entry_type_arguments) & toHex(len(payload.entry_arguments))
            args = payload.entry_arguments

        elif payload.`type` == ScriptPayload:
            
            var codeBcs : string
            serialize(payload.code, codeBcs)

            result = codeBcs & serializeArray(payload.script_type_arguments) & toHex(len(payload.script_arguments))
            args = payload.script_arguments

        for arg in args:

            result.add serializeJsonNode(arg)

    else:

        var serOutput : string
        serialize(payload, serOutput)

        return serOutput

proc encodeTransaction*(transaction : RawTransaction) : string =
    
    if transaction.isNil():

        raise newException(InvalidTransaction, "transaction is nil")
    
    let transaction = transaction[]
    for key, value in fieldPairs(transaction):
        
        when key == "payload":
            
            result.add encodePayload(value)

        else:

            var serOutput : string
            serialize(value, serOutput)

            result.add serOutput

