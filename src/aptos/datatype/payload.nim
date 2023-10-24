import std / [json]
import pkg / [jsony]
from std / strutils import parseEnum
from std / jsonutils import toJson

import move, writeset

type

    PayloadType* = enum

        WriteSetPayload = "write_set_payload"
        EntryFunction = "entry_function_payload"
        ScriptPayload = "script_payload"
        ModuleBundle = "module_bundle_payload"
        Multisig = "multisig_payload"
    
    Payload* = object

        case `type`* : PayloadType
        of ModuleBundle:

            modules : seq[MoveModule]

        of Multisig:

            multisig_address : string
            transaction_payload : ref Payload ## only for EntryFunction payload type

        of EntryFunction:

            function* : string
            entry_type_arguments* : seq[string]
            entry_arguments* : seq[BcsJsonType]

        of ScriptPayload:

            code* : MoveScriptBytecode
            script_type_arguments* : seq[string]
            script_arguments* : seq[BcsJsonType]

        of WriteSetPayload:

            write_set : WriteSet

proc toPayloadArgs*(args : tuple) : seq[BcsJsonType] =

    for val in fields(args):

        result.add newBcsType(%* val)

proc parseHook*(s : string, i : var int, v : var Payload) =

    var jsonPayload : JsonNode
    parseHook(s, i, jsonPayload)

    let payloadType = parseEnum[PayloadType](getStr(jsonPayload["type"]))
    case payloadType

    of EntryFunction:

        var entry_arguments : seq[BcsJsonType]
        for each in getElems(jsonPayload["arguments"]):

            entry_arguments.add newBcsType(each)

        v = Payload(
            `type` : EntryFunction,
            function : getStr(jsonPayload["function"]),
            entry_type_arguments : jsonPayload["type_arguments"].to(seq[string]),
            entry_arguments : entry_arguments
        )

    of ScriptPayload:

        var script_arguments : seq[BcsJsonType]
        for each in getElems(jsonPayload["arguments"]):

            script_arguments.add newBcsType(each)

        v = Payload(
            `type` : ScriptPayload,
            code : jsonPayload["code"].to(MoveScriptBytecode),
            script_type_arguments : jsonPayload["type_arguments"].to(seq[string]),
            script_arguments : script_arguments
        )

    of Multisig:

        v = Payload(
            `type` : payloadType,
            multisig_address : getStr(jsonPayload["multisig_address"]),
            transaction_payload : ($jsonPayload["transaction_payload"]).fromJson(ref Payload)
        )

    of ModuleBundle:

        v = Payload(
            `type` : payloadType,
            modules : ($jsonPayload["modules"]).fromJson(seq[MoveModule])
        )

    of WriteSetPayload:

        v = Payload(
            `type` : payloadType,
            write_set : ($jsonPayload["write_set"]).fromJson(WriteSet)
        )

proc toJsonStr(data : tuple) : string = jsony.toJson(jsonutils.toJson(data))

proc dumpHook*(s : var string, v : Payload) =

    case v.`type`

    of EntryFunction:

        var entry_arguments : seq[JsonNode]
        for each in v.entry_arguments:

            entry_arguments.add each.bcsVal()

        s = (
            `type` : $v.`type`,
            function : v.function,
            type_arguments : v.entry_type_arguments,
            arguments : entry_arguments
        ).toJsonStr()

    of ScriptPayload:

        var script_arguments : seq[JsonNode]
        for each in v.script_arguments:

            script_arguments.add each.bcsVal()

        s = (
            `type` : $v.`type`,
            code : v.code,
            type_arguments : v.script_type_arguments,
            arguments : script_arguments
        ).toJsonStr()

    of Multisig:

        s = (
            `type` : $v.`type`,
            multisig_address : v.multisig_address ,
            transaction_payload : v.transaction_payload
        ).toJsonStr()

    of ModuleBundle:

        s = (
            `type` : $v.`type`,
            modules : v.modules
        ).toJsonStr()

    of WriteSetPayload:

        s = (
            `type` : v.`type`,
            write_set : v.write_set
        ).toJsonStr()

proc `$`*(data : Payload) : string = jsony.toJson(data)

