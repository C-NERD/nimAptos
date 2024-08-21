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

        modules*: seq[MoveModule]

    EntryFunctionPayload* = object

        moduleid*: ModuleId
        function*: string
        type_arguments*: seq[string]    ## seq of TypeTags
        arguments*: seq[EntryArguments] ## seq of EntryArguments

    ScriptPayload* = object

        code*: MoveScriptBytecode
        type_arguments*: seq[string]     ## seq of TypeTags
        arguments*: seq[ScriptArguments] ## seq of ScriptArguments

    MultisigPayload* = object

        multisig_address*: string
        transaction_payload*: EntryFunctionPayload

    WriteSetPayload* = object

        write_set*: WriteSet

proc toBcsHook*[T: EntryFunctionPayload](data: T, output: var HexString) =

    ## serialize payload variant
    for val in serializeUleb128(2'u32): ## variant 2

        output.add serialize(val)

    ## serialize module id object
    toBcsHook(data.moduleid, output)

    ## serialize function name
    output.add serializeStr(data.function)

    ## serialize type_arguments
    for val in serializeUleb128(uint32(len(data.type_arguments))):

        output.add serialize(val)

    for item in data.type_arguments:

        toBcsHook(initTypeTag(item), output)

    ## serializing arguments
    for val in serializeUleb128(uint32(len(data.arguments))):

        output.add serialize(val)

    for item in data.arguments:

        toBcsHook(item, output)

proc toBcsHook*[T: ScriptPayload](payload: T, output: var HexString) =

    ## serialize payload variant
    for val in serializeUleb128(0'u32): ## variant 0

        output.add serialize(val)

    ## serialize payload bytecode
    for val in serializeUleb128(uint32(len(payload.code.bytecode) / 2)):

        output.add serialize(val)

    var bytecode = payload.code.bytecode
    removePrefix(bytecode, "0x")
    output.add bytecode

    ## serialize type_arguments
    for val in serializeUleb128(uint32(len(payload.type_arguments))):

        output.add serialize(val)

    for item in payload.type_arguments:

        toBcsHook(initTypeTag(item), output)

    ## serializing arguments
    for val in serializeUleb128(uint32(len(payload.arguments))):

        output.add serialize(val)

    for item in payload.arguments:

        toBcsHook(item, output)

proc toBcsHook*(data: ModuleBundlePayload, output: var HexString) =

    ## serialize payload variant
    #[for val in serializeUleb128(1'u32): ## variant 1

        result.add serialize[uint8](val)]#

    raise newException(NotImplemented, "ModuleBundlePayload bcs serialization not implemented yet")
    #{.fatal : "ModuleBundlePayload bcs serialization not implemented yet".}

proc fromBcsHook*(data: var HexString, output: var ModuleBundlePayload) =

    #let variant = deSerializeUleb128(payload) ## deserialize variant
    raise newException(NotImplemented, "ModuleBundlePayload bcs deserialization not implemented yet")
    #{.fatal : "ModuleBundlePayload bcs deSerialization not implemented yet".}

proc fromBcsHook*[T: EntryFunctionPayload](
    data: var HexString, output: var T) =

    #[let variant = deSerializeUleb128(payload) ## deserialize variant
    result.moduleid = deSerialize(payload) ## deserialize module id
    result.function = deSerializeStr(payload) ## deserialize function name

    let type_arg_len = deSerializeUleb128(payload)
    for _ in 0..<type_arg_len:

        result.type_arguments.add toJson(typetag.deSerialize(payload))

    let arg_len = deSerializeUleb128(payload)
    for _ in 0..<arg_len:

        result.arguments.add arguments.deSerialize(payload)]#
    raise newException(NotImplemented, "EntryFunctionPayload bcs deserializatio not implemented yet") ## problem in deSerializing EntryArguments cleanly
    #{.fatal : "EntryFunctionPayload bcs deSerialization not implemented yet".}

proc fromBcsHook*[T: ScriptPayload](data: var HexString, output: var T) =

    #let variant = deSerializeUleb128(payload) ## deserialize variant
    raise newException(NotImplemented, "ScriptPayload bcs deserialization not implemented yet")
    #{.fatal : "ScriptPayload bcs deSerialization not implemented yet".}

proc fromJsonHook*(v: var EntryFunctionPayload, s: JsonNode) =

    let payloadTypeParts = getStr(s["function"]).split("::")
    v = EntryFunctionPayload(
        moduleid: newModuleid(fmt"{payloadTypeParts[0]}::{payloadTypeParts[1]}"),
        function: payloadTypeParts[^1],
        type_arguments: jsonTo(s["type_arguments"], seq[string]),
        arguments: jsonTo(s["arguments"], seq[EntryArguments])
    )

proc fromJsonHook*(v: var ScriptPayload, s: JsonNode) =

    v = ScriptPayload(
        code: jsonTo(s["code"], MoveScriptBytecode),
        type_arguments: jsonTo(s["type_arguments"], seq[string]),
        arguments: jsonTo(s["arguments"], seq[ScriptArguments])
    )

proc fromJsonHook*(v: var ModuleBundlePayload, s: JsonNode) =

    raise newException(NotImplemented, "ModuleBundlePayload json deserialization not implemented yet")
    #{.fatal : "ModuleBundlePayload json serialization not implemented yet".}

proc toJsonHook*(v: EntryFunctionPayload): JsonNode =

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

proc toJsonHook*(v: ScriptPayload): JsonNode =

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

proc toJsonHook*(v: ModuleBundlePayload): JsonNode =

    raise newException(NotImplemented, "ModuleBundlePayload json serialization not implemented yet")
    #{.fatal : "ModuleBundlePayload json deSerialization not implemented yet".}

when isMainModule:

    let empty: seq[EntryArguments] = @[]
    let payload = EntryFunctionPayload(
        moduleid: newModuleId("0x3::token"),
        function: "create_token_script",
        type_arguments: @[],
        arguments: @[
            extendedEArg "collection name", extendedEArg "name name",
            extendedEArg "description", eArg 5'u8, eArg 5'u8,
            extendedEArg "http://somewhere.come",
            eArg uint64(1000000), extendedEArg(@[eArg false, eArg false,
                    eArg false, eArg false, eArg false]),
            extendedEArg(empty), extendedEArg(empty), extendedEArg(empty)
        ]
    )
    echo toJson(payload)

