#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementation for aptos node types

import std / [json, jsonutils]
from std / options import isNone, Option, get

type

    Error* = object

        message, error_code: string
        vm_error_code: int

    AccountData* = object

        sequence_number: uint64
        authentication_key: string

    ViewRequest*[T: tuple] = object

        function*: string
        type_arguments*: seq[string]
        arguments*: Option[T] ## serialize tuple to json as an array

    LedgerInfo* = object

        chain_id*: uint8
        epoch*, ledger_version*, oldest_ledger_version*, ledger_timestamp*,
            node_role*, oldest_block_height*, block_height*, git_hash * : string

    Block* = object

        block_height*, block_hash*, block_timestamp*, first_version*,
            last_version*: string
        transactions*: JsonNode

proc toJsonHook*(v: ViewRequest): JsonNode =

    var s = "{\"function\" : \"" & v.function & "\","
    s.add "\"type_arguments\" : " & $toJson(v.type_arguments) & ","
    if v.arguments.isNone():

        s.add "\"arguments\" : []}"

    else:

        var args = "["
        let arguments = v.arguments.get()
        for each in arguments.fields():

            args.add $toJson(each)

        args.add "]"
        s.add "\"arguments\" : " & args & "}"

    return parseJson(s)

