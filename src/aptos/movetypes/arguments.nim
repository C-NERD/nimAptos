#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#
## implementation for aptos payload arguments

{.experimental: "codeReordering".}

import std / [json]
from std / strutils import parseBiggestUInt, toHex, isEmptyOrWhitespace
from std / strformat import fmt

import pkg / [bcs, jsony]
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
        
        case `type` : ArgumentsEnum

        of U8:

            u8_arg : uint8

        of U16:

            u16_arg : uint16

        of U32:

            u32_arg : uint32

        of U64:

            u64_arg : uint64

        of U128:

            u128_arg : uint128

        of U256:

            u256_arg : uint256

        of Addr:

            addr_arg : Address

        of Hex:

            hex_arg : HexString
            data : string ## json serialization for data of hex, for seq and string

        of Bool:

            bool_arg : bool

    EntryArguments* = ref object of Arguments
        
        case `type` : ArgumentsEnum

        of U8:

            u8_arg : uint8

        of U16:

            u16_arg : uint16

        of U32:

            u32_arg : uint32

        of U64:

            u64_arg : uint64

        of U128:

            u128_arg : uint128

        of U256:

            u256_arg : uint256

        of Addr:

            addr_arg : Address

        of Hex:

            hex_arg : HexString
            data : string ## json serialization for data of hex, for seq and string

        of Bool:

            bool_arg : bool

template variant(data : ArgumentsBase) : untyped =

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

        raise newException(NotImplemented, "variant not implemented for " & $typeof(data))

proc baseSerializeScriptArg(data : ArgumentsBase) : HexString =
    
    result.add serialize[uint8](uint8(variant(data)))
    when data is HexString:
        
        ## serialize as bytes
        for val in serializeUleb128(uint32(len(data) / 2)):

            result.add serialize[uint8](val)
        
        result.add data

    elif data is Address:

        result.add address.serialize(data)

    else:

        result.add bcs.serialize[typeof(data)](data)

proc baseSerializeEntryArg(data : ArgumentsBase, asByte : bool = true) : HexString =
    
    var hex : HexString
    when data is HexString:
        
        ## serialize as bytes
        for val in serializeUleb128(uint32(len(data) / 2)):

            hex.add serialize[uint8](val)

        hex.add data

    elif data is Address:

        hex.add address.serialize(data)

    else:

        hex.add bcs.serialize[typeof(data)](data)
    
    if asByte:

        for val in serializeUleb128(uint32(len(hex) / 2)):

            result.add serialize[uint8](val)

    result.add hex

template baseDeSerializeScriptArg(data : var HexString, customcode : untyped) : untyped =

    var variant = bcs.deSerialize[uint8](data)
    if variant == 0:

        var base {.inject.} = bcs.deSerialize[uint8](data)
        customcode

    elif variant == 1:

        var base {.inject.} = bcs.deSerialize[uint64](data)
        customcode

    elif variant == 2:

        var base {.inject.} = bcs.deSerialize[uint128](data)
        customcode

    elif variant == 3:

        var base {.inject.} = address.deSerialize(data)
        customcode

    elif variant == 4:

        var base {.inject.} = bcs.deSerialize[string](data) ## implement code to properly deserialize hex string
        customcode

    elif variant == 5:

        var base {.inject.} = bcs.deSerialize[bool](data)
        customcode

    elif variant == 6:

        var base {.inject.} = bcs.deSerialize[uint16](data)
        customcode

    elif variant == 7:

        var base {.inject.} = bcs.deSerialize[uint32](data)
        customcode

    elif variant == 8:

        var base {.inject.} = bcs.deSerialize[uint256](data)
        customcode

    else:

        raise newException(ValueError, "Invalid variant from bcs")

converter sArg*(data : ArgumentsBase) : ScriptArguments =

    when data is uint8:

        return ScriptArguments(`type` : U8, u8_arg : data)

    elif data is uint16:

        return ScriptArguments(`type` : U16, u16_arg : data)

    elif data is uint32:

        return ScriptArguments(`type` : U32, u32_arg : data)

    elif data is uint64:

        return ScriptArguments(`type` : U64, u64_arg : data)

    elif data is uint128:

        return ScriptArguments(`type` : U128, u128_arg : data)

    elif data is uint256:

        return ScriptArguments(`type` : U256, u256_arg : data)

    elif data is Address:

        return ScriptArguments(`type` : Addr, addr_arg : data)

    elif data is HexString:

        return ScriptArguments(`type` : Hex, hex_arg : data)

    elif data is bool:

        return ScriptArguments(`type` : Bool, bool_arg : data)

    else:

        {.fatal : $typeof(data) & " is not supported for script arguments".}

converter eArg*(data : ArgumentsBase) : EntryArguments =

    when data is uint8:

        return EntryArguments(`type` : U8, u8_arg : data)

    elif data is uint16:

        return EntryArguments(`type` : U16, u16_arg : data)

    elif data is uint32:

        return EntryArguments(`type` : U32, u32_arg : data)

    elif data is uint64:

        return EntryArguments(`type` : U64, u64_arg : data)

    elif data is uint128:

        return EntryArguments(`type` : U128, u128_arg : data)

    elif data is uint256:

        return EntryArguments(`type` : U256, u256_arg : data)

    elif data is Address:

        return EntryArguments(`type` : Addr, addr_arg : data)

    elif data is HexString:

        return EntryArguments(`type` : Hex, hex_arg : data)

    elif data is bool:

        return EntryArguments(`type` : Bool, bool_arg : data)

    else:

        {.fatal : $typeof(data) & " is not supported for entry function arguments".}

converter extendedSArg*[T : seq[ScriptArguments] | seq[seq] | string](data : T) : ScriptArguments =

    when T is string:

        return ScriptArguments(`type` : Hex, hex_arg : fromString(toHex(data)), data : "\"" & data & "\"")

    elif T is seq:

        return ScriptArguments(`type` : Hex, hex_arg : fromSeq(data), data : jsony.toJson(data))

    else:

        {.fatal : $typeof(data) & " is not supported as extended script argument".}

converter extendedEArg*[T : seq[EntryArguments] | seq[seq] | string](data : T) : EntryArguments =

    when T is string:

        return EntryArguments(`type` : Hex, hex_arg : fromString(toHex(data)), data : "\"" & data & "\"")

    elif T is seq:
        
        return EntryArguments(`type` : Hex, hex_arg : fromSeq(data), data : jsony.toJson(data))

    else:

        {.fatal : $typeof(data) & " is not supported as extended entry function argument".}

template toBase*(data : ScriptArguments | EntryArguments, custom : untyped) : untyped {.dirty.} =
    
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

proc serialize*(data : EntryArguments, asByte : bool = true) : HexString =
    
    toBase data:

        return baseSerializeEntryArg(base, asByte)

#[proc deSerialize*(data : var HexString) : EntryArguments =

    raise newException(NotImplemented , "Not implemented yet")]#

proc serialize*(data : ScriptArguments) : HexString =

    toBase data:

        return baseSerializeScriptArg(base)

proc deSerialize*(data : var HexString) : ScriptArguments =

    baseDeSerializeScriptArg(data):

        return sArg base

proc fromSeq[T : seq[ScriptArguments] | seq[EntryArguments] | seq[seq]](data : T) : HexString = 

    when not (T is seq[ScriptArguments] or T is seq[EntryArguments] or T is seq[seq]):

        {.fatal : "seq child type " & $(T) & " not supported".}
    
    for val in serializeUleb128(uint32(len(data))):

        result.add bcs.serialize[uint8](val)

    when T is seq[seq]:

        for item in data:

            result.add fromSeq(item)

    else:

        for item in data:

            result.add serialize(item)

## TODO :: confirm if payload response is returned as string regardless of type
proc parseHook*(s : string, i : var int, v : var ScriptArguments) =

    var jsonHook : JsonNode
    parseHook(s, i, jsonHook)

    case jsonHook.kind

    of JString:

        let data = getStr(jsonHook)
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

            v = sArg newAddress(data)

    of JInt:

        let data = getInt(jsonHook)
        v = sArg uint32(data)

    of JBool:

        let data = getBool(jsonHook)
        v = sArg data

    else:

        raise newException(ValueError, fmt"Invalid json type {jsonHook.kind} for ScriptArguments")

proc parseHook*(s : string, i : var int, v : var EntryArguments) =

    var jsonHook : JsonNode
    parseHook(s, i, jsonHook)

    case jsonHook.kind

    of JString:

        let data = getStr(jsonHook)
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

            v = newAddress(data)

    of JInt:

        let data = getInt(jsonHook)
        v = eArg uint32(data) ## assumes that all integers are uint32

    of JBool:

        let data = getBool(jsonHook)
        v = eArg data

    else:

        raise newException(ValueError, fmt"Invalid json type {jsonHook.kind} for EntryArguments")

proc dumpHook*(s : var string, v : ScriptArguments) =

    toBase v:
        
        if v.`type` == Addr or v.`type` == Bool or v.`type` == U8 or v.`type` == U16 or v.`type` == U32:
            ## uint8, uint16 and uint32 are serialized normally

            s = toJson(base)

        elif v.`type` == Hex:

            if v.data.isEmptyOrWhitespace():

                s = toJson(base)

            else:

                s = v.data

        else:

            s = "\"" & toJson(base) & "\""

proc dumpHook*(s : var string, v : EntryArguments) =

    toBase v:
        
        if v.`type` == Addr or v.`type` == Bool or v.`type` == U8 or v.`type` == U16 or v.`type` == U32:

            s = toJson(base)

        elif v.`type` == Hex:

            if v.data.isEmptyOrWhitespace():

                s = toJson(base)

            else:

                s = v.data

        else:

            s = "\"" & toJson(base) & "\""

when isMainModule:

    let data = @[eArg false, eArg true]
    echo serialize(eArg data)
