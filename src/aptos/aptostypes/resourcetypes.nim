#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementations for aptos resource types

import std / [json]

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

