#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#
## implementation for aptos payload arguments

{.experimental: "codeReordering".}

import std / [json, jsonutils]
from std / strutils import parseBiggestUInt, toHex, isEmptyOrWhitespace
from std / strformat import fmt

import pkg / [bcs]
import address

from ../errors import NotImplemented

type

    ArgumentsBase* = SomeUnsignedInt | uint128 | uint256 | Address | HexString | bool
    ## These represents native move types
    ## HexString represents vector<u8> which is bytes

    ArgumentsEnum* {.pure.} = enum

        U8, U16, U32, U64, U128, U256, Addr, Bool, Hex

    Arguments = ref object of RootObj

    ScriptArguments* = ref object of Arguments

        case `type`: ArgumentsEnum

        of U8:

            u8_arg: uint8

        of U16:

            u16_arg: uint16

        of U32:

            u32_arg: uint32

        of U64:

            u64_arg: uint64

        of U128:

            u128_arg: uint128

        of U256:

            u256_arg: uint256

        of Addr:

            addr_arg: Address

        of Hex:

            hex_arg: HexString
            data: JsonNode ## json serialization for data of hex, for seq and string

        of Bool:

            bool_arg: bool

    EntryArguments* = ref object of Arguments

        case `type`: ArgumentsEnum

        of U8:

            u8_arg: uint8

        of U16:

            u16_arg: uint16

        of U32:

            u32_arg: uint32

        of U64:

            u64_arg: uint64

        of U128:

            u128_arg: uint128

        of U256:

            u256_arg: uint256

        of Addr:

            addr_arg: Address

        of Hex:

            hex_arg: HexString
            data: JsonNode ## json serialization for data of hex, for seq and string

        of Bool:

            bool_arg: bool

template variant(data: ArgumentsBase): untyped =

    when data is uint8:

        0

    elif data is uint64:

        1

    elif data is uint128:

        2

    elif data is Address:

        3

    elif data is HexString:

        4

    elif data is bool:

        5

    elif data is uint16:

        6

    elif data is uint32:

        7

    elif data is uint256:

        8

    else:

        raise newException(NotImplemented, "variant not implemented for " &
                $typeof(data))

converter sArg*(data: ArgumentsBase): ScriptArguments =

    when data is uint8:

        return ScriptArguments(`type`: U8, u8_arg: data)

    elif data is uint16:

        return ScriptArguments(`type`: U16, u16_arg: data)

    elif data is uint32:

        return ScriptArguments(`type`: U32, u32_arg: data)

    elif data is uint64:

        return ScriptArguments(`type`: U64, u64_arg: data)

    elif data is uint128:

        return ScriptArguments(`type`: U128, u128_arg: data)

    elif data is uint256:

        return ScriptArguments(`type`: U256, u256_arg: data)

    elif data is Address:

        return ScriptArguments(`type`: Addr, addr_arg: data)

    elif data is HexString:

        return ScriptArguments(`type`: Hex, hex_arg: data)

    elif data is bool:

        return ScriptArguments(`type`: Bool, bool_arg: data)

    else:

        {.fatal: $typeof(data) & " is not supported for script arguments".}

converter eArg*(data: ArgumentsBase): EntryArguments =

    when data is uint8:

        return EntryArguments(`type`: U8, u8_arg: data)

    elif data is uint16:

        return EntryArguments(`type`: U16, u16_arg: data)

    elif data is uint32:

        return EntryArguments(`type`: U32, u32_arg: data)

    elif data is uint64:

        return EntryArguments(`type`: U64, u64_arg: data)

    elif data is uint128:

        return EntryArguments(`type`: U128, u128_arg: data)

    elif data is uint256:

        return EntryArguments(`type`: U256, u256_arg: data)

    elif data is Address:

        return EntryArguments(`type`: Addr, addr_arg: data)

    elif data is HexString:

        return EntryArguments(`type`: Hex, hex_arg: data)

    elif data is bool:

        return EntryArguments(`type`: Bool, bool_arg: data)

    else:

        {.fatal: $typeof(data) & " is not supported for entry function arguments".}

template toBase*(data: ScriptArguments | EntryArguments,
        custom: untyped): untyped {.dirty.} =

    case data.`type`

    of U8:

        let base = data.u8_arg
        custom

    of U16:

        let base = data.u16_arg
        custom

    of U32:

        let base = data.u32_arg
        custom

    of U64:

        let base = data.u64_arg
        custom

    of U128:

        let base = data.u128_arg
        custom

    of U256:

        let base = data.u256_arg
        custom

    of Addr:

        let base = data.addr_arg
        custom

    of Hex:

        let base = data.hex_arg
        custom

    of Bool:

        let base = data.bool_arg
        custom

template baseDeSerializeScriptArg(data: var HexString,
        custom: untyped): untyped =

    var variant = bcs.deSerialize[uint8](data)
    if variant == 0:

        var base {.inject.} = bcs.deSerialize[uint8](data)
        custom

    elif variant == 1:

        var base {.inject.} = bcs.deSerialize[uint64](data)
        custom

    elif variant == 2:

        var base {.inject.} = bcs.deSerialize[uint128](data)
        custom

    elif variant == 3:

        var base {.inject.} = address.deSerialize(data)
        custom

    elif variant == 4:

        var base {.inject.} = bcs.deSerialize[HexString](
                data) ## TODO :: implement code to properly deserialize hex string
        custom

    elif variant == 5:

        var base {.inject.} = bcs.deSerialize[bool](data)
        custom

    elif variant == 6:

        var base {.inject.} = bcs.deSerialize[uint16](data)
        custom

    elif variant == 7:

        var base {.inject.} = bcs.deSerialize[uint32](data)
        custom

    elif variant == 8:

        var base {.inject.} = bcs.deSerialize[uint256](data)
        custom

    else:

        raise newException(ValueError, "Invalid variant from bcs")

proc serialize*(data: ScriptArguments): HexString =

    toBase data:

        result.add bcs.serialize[uint8](uint8(variant(base)))
        when base is Address:

            result.add address.serialize(base)

        elif base is HexString:

            if isNil(data.data):

                result.add bcs.serialize[HexString](base)

            else:

                result.add base

        else:

            result.add bcs.serialize[typeof(base)](base)

proc serialize*(data: EntryArguments, asBytes: bool = true): HexString =

    toBase data:

        var hex: HexString
        when base is Address:

            hex.add address.serialize(base)

        elif base is HexString:

            if isNil(data.data): ## checks if is pure Hex

                hex.add bcs.serialize[HexString](base)

            else: ## if is hex gotten from string or seq

                hex.add base

        else:

            hex.add bcs.serialize[typeof(base)](base)

        if asBytes: ## false when used by extendedEArg

            for val in serializeUleb128(uint32(byteLen(hex))):

                result.add bcs.serialize[uint8](val)

        result.add(hex)

proc deSerialize*[T: ScriptArguments | EntryArguments](data: var HexString): T =

    when T is ScriptArguments:

        baseDeSerializeScriptArg(data):

            return sArg base

    elif T is EntryArguments:

        raise newException(NotImplemented, "Not implemented yet")

proc fromSeq[T: seq[ScriptArguments] | seq[EntryArguments] | seq[seq]](
    data: T): HexString =

    when not (T is seq[ScriptArguments] or T is seq[EntryArguments] or T is seq[seq]):

        {.fatal: "seq child type " & $(T) & " not supported".}

    for val in serializeUleb128(uint32(len(data))):

        result.add bcs.serialize[uint8](val)

    when T is seq[seq]:

        for item in data:

            result.add fromSeq(item)

    else:

        for item in data:

            when item is ScriptArguments:

                result.add serialize(item)

            elif item is EntryArguments:

                result.add serialize(item, false)

proc toJsonHook*(v: ScriptArguments): JsonNode =

    toBase v:

        if v.`type` == Addr or v.`type` == Bool or v.`type` == U8 or v.`type` ==
                U16 or v.`type` == U32:
            ## uint8, uint16 and uint32 are serialized normally

            return toJson(base)

        elif v.`type` == Hex:

            if not isNil(v.data):

                if v.data.kind == JNull:

                    return toJson(base)

                else:

                    return v.data

            else:

                return toJson(base)

        else:

            return toJson($base)

proc toJsonHook*(v: EntryArguments): JsonNode =

    toBase v:

        if v.`type` == Addr or v.`type` == Bool or v.`type` == U8 or v.`type` ==
                U16 or v.`type` == U32:

            return toJson(base)

        elif v.`type` == Hex:

            if not isNil(v.data):

                if v.data.kind == JNull:

                    return toJson(base)

                else:

                    return v.data

            else:

                return toJson(base)

        else:

            return toJson($base)

proc toJsonHook(v: seq[ScriptArguments]): JsonNode =

    result = newJArray()
    for each in v:

        result.add toJsonHook(each)

proc toJsonHook(v: seq[EntryArguments]): JsonNode =

    result = newJArray()
    for each in v:

        result.add toJsonHook(each)

converter extendedSArg*[T: seq[ScriptArguments] | string](
    data: T): ScriptArguments =

    #[when T is HexString:

        return ScriptArguments(`type` : Hex, hex_arg : data, data : toJson($data))]#

    when T is string:

        return ScriptArguments(`type`: Hex, hex_arg: bcs.serializeStr(data),
                data: toJson(data))

    elif T is seq:

        return ScriptArguments(`type`: Hex, hex_arg: fromSeq(data),
                data: toJsonHook(data))

    else:

        {.fatal: $typeof(data) & " is not supported as extended script argument".}

converter extendedEArg*[T: seq[EntryArguments] | string](
    data: T): EntryArguments =

    when T is string:

        return EntryArguments(`type`: Hex, hex_arg: bcs.serializeStr(data),
                data: toJson(data))

    elif T is seq:

        return EntryArguments(`type`: Hex, hex_arg: fromSeq(data),
                data: toJsonHook(data))

    else:

        {.fatal: $typeof(data) & " is not supported as extended entry function argument".}

## TODO :: confirm if payload response is returned as string regardless of type
proc fromJsonHook*(v: var ScriptArguments, s: JsonNode) =

    case s.kind

    of JString:

        let data = getStr(s)
        try:

            let idata = newUInt256 data
            v = sArg idata
            return

        except:

            discard

        if not isValidAddress(data): ## TODO :: serialize string to hex

            try:

                v = sArg fromString(data)

            except bcs.InvalidHex:

                v = sArg data

        else:

            v = sArg initAddress(data)

    of JInt:

        let data = getInt(s)
        v = sArg uint32(data)

    of JBool:

        let data = getBool(s)
        v = sArg data

    of JArray:

        var data: seq[ScriptArguments]
        for item in s:

            var itemData: ScriptArguments
            fromJsonHook(itemData, item)

            data.add itemData

        v = extendedSArg data

    else:

        raise newException(ValueError, fmt"Invalid json type {s.kind} for ScriptArguments")

proc fromJsonHook*(v: var EntryArguments, s: JsonNode) =

    case s.kind

    of JString:

        let data = getStr(s)
        ## TODO :: improve json parsing for ScriptArguments and EntryArguments
        try:

            let idata = newUInt256 data ## assumes that all string serialized integers are uint256
            v = eArg idata
            return

        except:

            discard

        if not isValidAddress(data):

            try:

                v = eArg fromString(data) ## TODO :: improve hex detection at bcs

            except bcs.InvalidHex:

                v = eArg data

        else:

            v = eArg initAddress(data)

    of JInt:

        let data = getInt(s)
        v = eArg uint32(data) ## assumes that all integers are uint32

    of JBool:

        let data = getBool(s)
        v = eArg data

    of JArray:

        var data: seq[EntryArguments]
        for item in s:

            var itemData: EntryArguments
            fromJsonHook(itemData, item)

            data.add itemData

        v = extendedEArg data

    else:

        raise newException(ValueError, fmt"Invalid json type {s.kind} for EntryArguments")

when isMainModule:

    let data = extendedEArg @[extendedEArg @[eArg false, eArg true],
            extendedEArg @[eArg 2'u8, eArg false]]
    echo toJson(data)
    echo serialize(data)

