#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementation for aptos payload

import std / [json, jsonutils, tables, strutils]
from std / strformat import fmt

import pkg / [bcs]

import ../ [resourcetypes]
import writeset, moduleid
import ../../movetypes/[arguments, typetag]

from ../../errors import NotImplemented

type

    TransactionPayload* = ModuleBundlePayload | EntryFunctionPayload | ScriptPayload

    ModuleBundlePayload* = object

        modules* : seq[MoveModule]  

    EntryFunctionPayload* = object

        moduleid* : ModuleId
        function* : string
        type_arguments* : seq[string] ## seq of TypeTags 
        arguments* : seq[EntryArguments] ## seq of EntryArguments

    ScriptPayload* = object

        code* : MoveScriptBytecode
        type_arguments* : seq[string] ## seq of TypeTags
        arguments* : seq[ScriptArguments] ## seq of ScriptArguments

    MultisigPayload* = object

        multisig_address* : string
        transaction_payload* : EntryFunctionPayload

    WriteSetPayload* = object

        write_set* :  WriteSet   

template serialize*[T : ModuleBundlePayload | ScriptPayload | EntryFunctionPayload](data : T) : untyped =

    when T is ModuleBundlePayload:

        serializeModulePayload(data)

    elif T is ScriptPayload:

        serializeScriptPayload(data)

    elif T is EntryFunctionPayload:

        serializeEntryFunction(data)

proc serializeEntryFunction*[T : EntryFunctionPayload](payload : T) : HexString =
        
    ## serialize payload variant
    for val in serializeUleb128(2'u32): ## variant 2

        result.add bcs.serialize[uint8](val)
        
    ## serialize module id object
    result.add moduleid.serialize(payload.moduleid)

    ## serialize function name
    result.add bcs.serializeStr(payload.function)

    ## serialize type_arguments
    for val in serializeUleb128(uint32(len(payload.type_arguments))):

        result.add bcs.serialize[uint8](val)
    
    for item in payload.type_arguments:

        result.add typetag.serialize(jsonTo(%item, TypeTags))

    ## serializing arguments
    for val in serializeUleb128(uint32(len(payload.arguments))):

        result.add bcs.serialize[uint8](val)

    for item in payload.arguments:
        
        result.add arguments.serialize(item)

proc serializeScriptPayload*[T : ScriptPayload](payload : T) : HexString =
        
    ## serialize payload variant
    for val in serializeUleb128(0'u32): ## variant 0

        result.add bcs.serialize[uint8](val)

    ## serialize payload bytecode
    for val in serializeUleb128(uint32(len(payload.code.bytecode) / 2)):

        result.add bcs.serialize[uint8](val)
    
    var bytecode = payload.code.bytecode
    removePrefix(bytecode, "0x")
    result.add bytecode
    
    ## serialize type_arguments
    for val in serializeUleb128(uint32(len(payload.type_arguments))):

        result.add bcs.serialize[uint8](val)

    for item in payload.type_arguments:

        result.add typetag.serialize(jsonTo(%item, TypeTags))

    ## serializing arguments 
    for val in serializeUleb128(uint32(len(payload.arguments))):

        result.add bcs.serialize[uint8](val)

    for item in payload.arguments:

        result.add arguments.serialize(item)

proc serializeModulePayload*(payload : ModuleBundlePayload) : HexString =

    ## serialize payload variant
    #[for val in serializeUleb128(1'u32): ## variant 1

        result.add serialize[uint8](val)]#

    raise newException(NotImplemented, "Not implemented yet")

template deSerialize*[T : ModuleBundlePayload | ScriptPayload | EntryFunctionPayload](data : var HexString) : untyped =

    when T is ModuleBundlePayload:

        deSerializeModulePayload(data)

    elif T is ScriptPayload:

        deSerializeScriptPayload(data)

    elif T is EntryFunctionPayload:

        deSerializeEntryFunction(data)

proc deSerializeModulePayload*(payload : var HexString) : ModuleBundlePayload =
    
    #let variant = deSerializeUleb128(payload) ## deserialize variant
    raise newException(NotImplemented, "Not implemented yet")

proc deSerializeEntryFunction*[T : EntryFunctionPayload](payload : var HexString) : T =
    
    #[let variant = deSerializeUleb128(payload) ## deserialize variant
    result.moduleid = deSerialize(payload) ## deserialize module id
    result.function = deSerializeStr(payload) ## deserialize function name

    let type_arg_len = deSerializeUleb128(payload)
    for _ in 0..<type_arg_len:

        result.type_arguments.add toJson(typetag.deSerialize(payload))
    
    let arg_len = deSerializeUleb128(payload)
    for _ in 0..<arg_len:

        result.arguments.add arguments.deSerialize(payload)]#
    raise newException(NotImplemented, "Not implemented yet") ## problem in deSerializing EntryArguments cleanly

proc deSerializeScriptPayload*[T : ScriptPayload](payload : var HexString) : T =
    
    #let variant = deSerializeUleb128(payload) ## deserialize variant
    raise newException(NotImplemented, "Not implemented yet")

proc fromJsonHook*(v : var EntryFunctionPayload, s : JsonNode) =

    let payloadTypeParts = getStr(s["function"]).split("::")
    v = EntryFunctionPayload(
        moduleid : newModuleid(fmt"{payloadTypeParts[0]}::{payloadTypeParts[1]}"),
        function : payloadTypeParts[^1],
        type_arguments : jsonTo(s["type_arguments"], seq[string]),
        arguments : jsonTo(s["arguments"], seq[EntryArguments])
    )

proc fromJsonHook*(v : var ScriptPayload, s : JsonNode) =

    v = ScriptPayload(
        code : jsonTo(s["code"], MoveScriptBytecode),
        type_arguments : jsonTo(s["type_arguments"], seq[string]),
        arguments : jsonTo(s["arguments"], seq[ScriptArguments])
    )

proc toJsonHook*(v : EntryFunctionPayload) : JsonNode =

    var s = "{\"type\" : \"entry_function_payload\","
    s.add "\"function\" : \"" & $v.moduleid & "::" & v.function & "\","
    s.add "\"type_arguments\" : " & $toJson(v.type_arguments) & ","
    s.add "\"arguments\" : ["

    let argsLen = len(v.arguments)
    for pos in 0..<argsLen:

        s.add $toJson(v.arguments[pos])
        if pos != argsLen - 1:

            s.add ","
    
    s.add "]}"
    return parseJson(s)

proc toJsonHook*(v : ScriptPayload) : JsonNode =

    var s = "{\"type\" : \"script_payload\","
    s.add "\"code\" : " & $toJson(v.code) & ","
    s.add "\"type_arguments\" : " & $toJson(v.type_arguments) & ","
    s.add "\"arguments\" : ["

    let argsLen = len(v.arguments)
    for pos in 0..<argsLen:

        s.add $toJson(v.arguments[pos])
        if pos != argsLen - 1:

            s.add ","
    
    s.add "]}"
    return parseJson(s)

#[proc toJsonHook*(v : ModuleBundlePayload) : JsonNode =

    raise newException(NotImplemented, "Not implemented yet")]#

when isMainModule:

    let empty : seq[EntryArguments] = @[]
    let payload = EntryFunctionPayload(
        moduleid : newModuleId("0x3::token"),
        function : "create_token_script",
        type_arguments : @[],
        arguments : @[
            extendedEArg "collection name", extendedEArg "name name", extendedEArg "description", eArg 5'u8, eArg 5'u8, extendedEArg "http://somewhere.come",
            eArg uint64(1000000), extendedEArg(@[eArg false, eArg false, eArg false, eArg false, eArg false]),
            extendedEArg(empty), extendedEArg(empty), extendedEArg(empty)
        ]
    )
    echo toJson(payload)

