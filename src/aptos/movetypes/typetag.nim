#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#
## implementation for move lang typetags

import std / [json, jsonutils]
from std / re import match, find, re
from std / strutils import strip, split
from std / strformat import fmt

import pkg / [bcs]

import address, identifier

type

    TypeTagsBase {.pure.} = enum

        Bool, U8, U64, U128, Addr, Signer, Vector, Struct, U16, U32, U256

    TypeTags* = object

        case `type`: TypeTagsBase

        of Vector:

            childtype: ref TypeTags

        of Struct:

            address: Address
            module, name: Identifier
            type_args: seq[TypeTags]

        else:

            discard

proc toBcsHook*(data: TypeTags, output: var HexString) =

    for val in serializeUleb128(uint32(ord(data.`type`))):

        output.add serialize(val)

    case data.`type`

    of Vector:

        toBcsHook(data.childtype[], output)

    of Struct:

        toBcsHook(data.address, output)
        toBcsHook(data.module, output)
        toBcsHook(data.name, output)

        ## serialize type_args
        for val in serializeUleb128(uint32(len(data.type_args))):

            output.add serialize(val)

        for child in data.type_args:

            toBcsHook(child, output)

    else:

        discard

proc fromBcsHook*(data: var HexString, output: var TypeTags) =

    let variant = deSerializeUleb128(data)
    case variant

    of 0:

        output = TypeTags(`type`: Bool)

    of 1:

        output = TypeTags(`type`: U8)

    of 2:

        output = TypeTags(`type`: U64)

    of 3:

        output = TypeTags(`type`: U128)

    of 4:

        output = TypeTags(`type`: Addr)

    of 5:

        output = TypeTags(`type`: Signer)

    of 6:

        output = TypeTags(
            `type`: Vector
        )
        fromBcsHook(data, output.childtype[])

    of 7:

        output = TypeTags(
            `type`: Struct,
            type_args: @[]
        )
        fromBcsHook(data, output.address)
        fromBcsHook(data, output.module)
        fromBcsHook(data, output.name)
        let argsLen = deSerializeUleb128(data)
        for _ in 0..<argsLen:

            var typeArg: TypeTags
            fromBcsHook(data, typeArg)
            output.type_args.add typeArg

    of 8:

        output = TypeTags(`type`: U16)

    of 9:

        output = TypeTags(`type`: U32)

    of 10:

        output = TypeTags(`type`: U256)

    else:

        raise newException(ValueError, "Invalid variant " & $variant)

proc fromJsonHook*(v: var TypeTags, s: JsonNode) =

    let s = getStr(s).strip()
    if not match(s, re"^(bool|u8|u64|u128|address|signer|vector<.+>|0x[0-9a-zA-Z:_<, >]+)$"):

        raise newException(ValueError, "Invalid type tag " & s)

    if s == "bool":

        v = TypeTags(`type`: Bool)

    elif s == "u8":

        v = TypeTags(`type`: U8)

    elif s == "u16":

        v = TypeTags(`type`: U16)

    elif s == "u32":

        v = TypeTags(`type`: U32)

    elif s == "u64":

        v = TypeTags(`type`: U64)

    elif s == "u128":

        v = TypeTags(`type`: U128)

    elif s == "u256":

        v = TypeTags(`type`: U256)

    elif s == "address":

        v = TypeTags(`type`: Addr)

    elif s == "signer":

        v = TypeTags(`type`: Signer)

    elif s[0..5] == "vector":

        let child = s[5..^1]
        v = TypeTags(`type`: Vector)
        v.childtype[] = jsonTo(%child[1..^2], TypeTags)

    elif match(s, re"^.*(::).*(::).*"): ## if it's a struct

        let argsPos = find(s, re"(<).*(>)")
        var
            ogStruct: string
            structArgs: string

        if argsPos != -1:

            structArgs = s[argsPos + 1..^2]
            ogStruct = s[0..argsPos - 1]

        else:

            ogStruct = s

        let parts = ogStruct.split("::")
        v = TypeTags(
            `type`: Struct,
            address: initAddress(parts[0]),
            module: initIdentifier(parts[1]),
            name: initIdentifier(parts[2]),
            type_args: @[]
        )
        if len(structArgs) > 0:

            for arg in structArgs.split(","):

                v.type_args.add jsonTo(%arg.strip(), TypeTags)

    else:

        raise newException(ValueError, "Invalid type tag " & s)

proc toJsonHook*(v: TypeTags): JsonNode =

    var s: string
    case v.`type`

    of Bool:

        s = "bool"

    of U8:

        s = "u8"

    of U16:

        s = "u16"

    of U32:

        s = "u32"

    of U64:

        s = "u64"

    of U128:

        s = "u128"

    of U256:

        s = "u256"

    of Addr:

        s = "address"

    of Signer:

        s = "signer"

    of Vector:

        s = fmt"vector<{getStr(toJson(v.childtype[]))}>"

    of Struct:

        s = fmt"{v.address}::{v.module}::{v.name}"
        let argsLen = len(v.type_args)
        if argsLen != 0:

            s.add "<"
            for pos in 0..<argsLen:

                s.add getStr(toJson(v.type_args[pos]))
                if pos != argsLen - 1:

                    s.add ", "

            s.add ">"

    return %s

proc initTypeTag*(data: string): TypeTags = jsonTo(%data, TypeTags)

when isMainModule:

    let struct = jsonTo(%"0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>", TypeTags)
    echo toJson(struct)
    echo serialize(struct)

