#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementations for aptos resource types

import std / [json]
import pkg / [jsony]

type

    GenericParam = object

        constraints* : seq[string]

    Struct* = object

        name* : string
        is_native* : bool
        abilities* : seq[string]
        generic_type_params* : seq[GenericParam]
        fields* : seq[tuple[name, `type` : string]]

    MoveFunction* = object

        name*, visibility* : string
        is_entry* : bool
        generic_type_params* : seq[GenericParam]
        params* : seq[string]
        `return`* : seq[string]

    MoveModule* = object

        address*, name* : string
        friends* : seq[string]
        exposed_functions* : seq[MoveFunction]
        structs* : seq[Struct]

    MoveModuleByteCode* = object

        bytecode* : string
        abi* : MoveModule

    MoveResource* = object

        `type`* : string
        data* : JsonNode

    MoveScriptBytecode* = object

        bytecode* : string
        abi* : MoveFunction

proc parseHook*(s : string, i : var int, v : var MoveResource) =

    var jsonResource : JsonNode
    parseHook(s, i, jsonResource)
    v = MoveResource(
        `type` : getStr(jsonResource["type"]),
        data : jsonResource["data"]
    )

proc parseHook*(s : string, i : var int, v : var Struct) =

    var jsonResource : JsonNode
    parseHook(s, i, jsonResource)
    v = Struct(
        name : getStr(jsonResource["name"]),
        is_native : getBool(jsonResource["is_native"]),
        abilities : ($jsonResource["abilities"]).fromJson(seq[string]),
        generic_type_params : ($jsonResource["generic_type_params"]).fromJson(seq[GenericParam]),
        fields : ($jsonResource["fields"]).fromJson(seq[tuple[name, `type` : string]])
    )

proc parseHook*(s : string, i : var int, v : var MoveFunction) =

    var jsonResource : JsonNode
    parseHook(s, i, jsonResource)
    v = MoveFunction(
        name : getStr(jsonResource["name"]),
        visibility : getStr(jsonResource["visibility"]),
        is_entry : getBool(jsonResource["is_entry"]),
        generic_type_params : ($jsonResource["generic_type_params"]).fromJson(seq[GenericParam]),
        params : ($jsonResource["params"]).fromJson(seq[string]),
        `return` : ($jsonResource["params"]).fromJson(seq[string])
    )

proc parseHook*(s : string, i : var int, v : var MoveModule) =

    var jsonResource : JsonNode
    parseHook(s, i, jsonResource)
    v = MoveModule(
        address : getStr(jsonResource["address"]),
        name : getStr(jsonResource["name"]),
        friends : ($jsonResource["friends"]).fromJson(seq[string]),
        exposed_functions : ($jsonResource["exposed_functions"]).fromJson(seq[MoveFunction]),
        structs : ($jsonResource["structs"]).fromJson(seq[Struct])
    )
