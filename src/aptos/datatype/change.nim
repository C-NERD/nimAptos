import std / [options, json]
import pkg / [jsony]
from std / strutils import parseEnum
from std / jsonutils import toJson

import move

type

    ChangeType* = enum

        DeleteModule = "delete_module"
        DeleteResource = "delete_resource"
        DeleteTableItem = "delete_table_item"
        WriteModule = "write_module"
        WriteResource = "write_resource"
        WriteTableItem = "write_table_item"

    Change* = object

        state_key_hash* : string
        case `type`* : ChangeType
        of DeleteModule:

            delete_module_address*, module* : string

        of DeleteResource:

            delete_resource_address*, resource* : string
        
        of WriteModule:

            write_module_address* : string
            write_module_data* : MoveModuleByteCode
        
        of WriteResource:

            write_resource_address* : string
            write_resource_data* : MoveResource

        of DeleteTableItem:

            delete_handle*, delete_key* : string
            delete_table_data* : tuple[key, key_type : string]

        of WriteTableItem:

            write_handle*, write_key*, value* : string
            write_table_data* : Option[tuple[key, key_type, value, value_type : string]]

proc parseHook*(s : string, i : var int, v : var Change) =

    var jsonChange : JsonNode
    parseHook(s, i, jsonChange)

    let changeType = parseEnum[ChangeType](getStr(jsonChange["type"]))
    case changeType

    of DeleteModule:

        v = Change(
            `type` : DeleteModule,
            state_key_hash : getStr(jsonChange["state_key_hash"]),
            delete_module_address : getStr(jsonChange["address"]),
            module : getStr(jsonChange["module"])
        )

    of DeleteResource:

        v = Change(
            `type` : DeleteResource,
            state_key_hash : getStr(jsonChange["state_key_hash"]),
            delete_resource_address : getStr(jsonChange["address"]),
            resource : getStr(jsonChange["resource"])
        )

    of DeleteTableItem:

        v = Change(
            `type` : DeleteTableItem,
            state_key_hash : getStr(jsonChange["state_key_hash"]),
            delete_handle : getStr(jsonChange["handle"]),
            delete_key : getStr(jsonChange["key"]),
            delete_table_data : fromJson($jsonChange["data"], tuple[key, key_type : string])
        )

    of WriteModule:

        v = Change(
            `type` : WriteModule,
            state_key_hash : getStr(jsonChange["state_key_hash"]),
            write_module_address : getStr(jsonChange["address"]),
            write_module_data : fromJson($jsonChange["data"], MoveModuleByteCode)
        )

    of WriteResource:

        v = Change(
            `type` : WriteResource,
            state_key_hash : getStr(jsonChange["state_key_hash"]),
            write_resource_address : getStr(jsonChange["address"]),
            write_resource_data : fromJson($jsonChange["data"], MoveResource)
        )

    of WriteTableItem:

        v = Change(
            `type` : WriteTableItem,
            state_key_hash : getStr(jsonChange["state_key_hash"]),
            write_handle : getStr(jsonChange["handle"]),
            write_key : getStr(jsonChange["key"]),
            value : getStr(jsonChange["value"]),
            write_table_data : fromJson($jsonChange["data"], Option[tuple[key, key_type, value, value_type : string]])
        )

proc toJsonStr(data : tuple) : string = jsony.toJson(jsonutils.toJson(data))

proc dumpHook*(s : var string, v : Change) =

    case v.`type`

    of DeleteModule:

        s = (
            `type` : $v.`type`,
            state_key_hash : v.state_key_hash,
            address : v.delete_module_address,
            module : v.module,
        ).toJsonStr()

    of DeleteResource:

        s = (
            `type` : $v.`type`,
            state_key_hash : v.state_key_hash,
            address : v.delete_resource_address,
            resource : v.resource
        ).toJsonStr()

    of DeleteTableItem:

        s = (
            `type` : $v.`type`,
            state_key_hash : v.state_key_hash,
            handle : v.delete_handle,
            key : v.delete_key,
            data : v.delete_table_data
        ).toJsonStr()

    of WriteModule:

        s = (
            `type` : $v.`type`,
            state_key_hash : v.state_key_hash,
            address : v.write_module_address,
            data : v.write_module_data
        ).toJsonStr()

    of WriteResource:

        s = (
            `type` : $v.`type`,
            state_key_hash : v.state_key_hash,
            address : v.write_resource_address,
            data : v.write_resource_data
        ).toJsonStr()

    of WriteTableItem:

        s = (
            `type` : $v.`type`,
            state_key_hash : v.state_key_hash,
            handle : v.write_handle,
            key : v.write_key,
            value : v.value,
            data : v.write_table_data
        ).toJsonStr()

proc `$`*(data : Change) : string = jsony.toJson(data)
