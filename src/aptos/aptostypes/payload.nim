import std / [json, tables, strutils]
from std / jsonutils import toJson, jsonTo 
#from std / options import Option, isNone
from std / strformat import fmt

import pkg / [bcs, jsony]

import resourcetypes, writeset, moduleid
import ../movetypes/[scriptarguments, typetag]

from ../errors import NotImplemented

type

    TransactionPayload* = ModuleBundlePayload | EntryFunctionPayload | ScriptPayload

    ModuleBundlePayload* = object

        modules* : seq[MoveModule]  

    EntryFunctionPayload* = object

        moduleid* : ModuleId
        function* : string
        type_arguments* : seq[string] ## tuple of TypeTags ## TODO :: check if error occurs here
        arguments* : seq[EntryArguments] ## tuple of ScriptArguments

    ScriptPayload* = object

        code* : MoveScriptBytecode
        type_arguments* : seq[string] ## tuple of TypeTags
        arguments* : seq[ScriptArguments] ## tuple of ScriptArguments

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

        result.add typetag.serialize(fromJson(item, TypeTags))

    ## serializing arguments
    for val in serializeUleb128(uint32(len(payload.arguments))):

        result.add bcs.serialize[uint8](val)

    for item in payload.arguments:

        result.add scriptarguments.serialize(item)

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

        result.add typetag.serialize(fromJson(item, TypeTags))

    ## serializing arguments 
    for val in serializeUleb128(uint32(len(payload.arguments))):

        result.add bcs.serialize[uint8](val)

    for item in payload.arguments:

        result.add scriptarguments.serialize(item)

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

        result.arguments.add scriptarguments.deSerialize(payload)]#
    raise newException(NotImplemented, "Not implemented yet") ## problem in deSerializing EntryArguments cleanly

proc deSerializeScriptPayload*[T : ScriptPayload](payload : var HexString) : T =
    
    #let variant = deSerializeUleb128(payload) ## deserialize variant
    raise newException(NotImplemented, "Not implemented yet")

proc parseHook*(s : string, i : var int, v : var EntryFunctionPayload) =

    var jsonPayload : JsonNode
    parseHook(s, i, jsonPayload)
    let payloadTypeParts = getStr(jsonPayload["function"]).split("::")
    v = EntryFunctionPayload(
        moduleid : newModuleid(fmt"{payloadTypeParts[0]}::{payloadTypeParts[1]}"),
        function : payloadTypeParts[^1],
        type_arguments : jsony.fromJson($jsonPayload["type_arguments"], seq[string]),
        arguments : jsony.fromJson($jsonPayload["arguments"], seq[EntryArguments])
    )

proc parseHook*(s : string, i : var int, v : var ScriptPayload) =

    var jsonPayload : JsonNode
    parseHook(s, i, jsonPayload)
    v = ScriptPayload(
        code : jsonTo(jsonPayload["code"], MoveScriptBytecode),
        type_arguments : jsony.fromJson($jsonPayload["type_arguments"], seq[string]),
        arguments : jsony.fromJson($jsonPayload["arguments"], seq[ScriptArguments])
    )

proc dumpHook*(s : var string, v : EntryFunctionPayload) =

    s.add "{\"type\" : \"entry_function_payload\","
    s.add "\"function\" : \"" & $v.moduleid & "::" & v.function & "\","
    s.add "\"type_arguments\" : " & $jsonutils.toJson(v.type_arguments) & ","
    s.add "\"arguments\" : ["

    let argsLen = len(v.arguments)
    for pos in 0..<argsLen:

        s.add jsony.toJson(v.arguments[pos])
        if pos != argsLen - 1:

            s.add ","
    
    s.add "]}"

proc dumpHook*(s : var string, v : ScriptPayload) =

    s.add "{\"type\" : \"script_payload\","
    s.add "\"code\" : \"" & $jsonutils.toJson(v.code) & "\","
    s.add "\"type_arguments\" : " & $jsonutils.toJson(v.type_arguments) & ","
    s.add "\"arguments\" : ["

    let argsLen = len(v.arguments)
    for pos in 0..<argsLen:

        s.add jsony.toJson(v.arguments[pos])
        if pos != argsLen - 1:

            s.add ","
    
    s.add "]}"

#[proc dumpHook*(s : var string, v : ModuleBundlePayload) =

    raise newException(NotImplemented, "Not implemented yet")]#

