#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#
## implementation for move lang typetags

from std / re import match, find, re
from std / strutils import strip, split
from std / strformat import fmt
import pkg / [bcs, jsony]
import address, identifier

type
    
    TypeTagsBase {.pure.} = enum

        Bool, U8, U64, U128, Addr, Signer, Vector, Struct, U16, U32, U256

    TypeTags* = object

        case `type` : TypeTagsBase

        of Vector:

            childtype : ref TypeTags

        of Struct:

            address : Address
            module, name : Identifier
            type_args : seq[TypeTags]

        else:

            discard

proc serialize*(data : TypeTags) : HexString =
    
    for val in serializeUleb128(uint32(ord(data.`type`))):

        result.add bcs.serialize(val)

    case data.`type`
    
    of Vector:

        result.add serialize data.childtype[]

    of Struct:

        result.add serialize(data.address)
        result.add serialize(data.module)
        result.add serialize(data.name)

        ## serialize type_args
        for val in serializeUleb128(uint32(len(data.type_args))):

            result.add serialize(val)

        for child in data.type_args:

            result.add serialize(child)

    else:

        discard

proc deSerialize*(data : var HexString) : TypeTags =

    let variant = deSerializeUleb128(data)
    case variant

    of 0:

        return TypeTags(`type` : Bool)

    of 1:

        return TypeTags(`type` : U8)

    of 2:

        return TypeTags(`type` : U64)
    
    of 3:

        return TypeTags(`type` : U128)

    of 4:

        return TypeTags(`type` : Addr)

    of 5:

        return TypeTags(`type` : Signer)

    of 6:

        result = TypeTags(
            `type` : Vector 
        )
        result.childtype[] = deSerialize(data)

    of 7:

        result = TypeTags(
            `type` : Struct,
            address : address.deSerialize(data),
            module : identifier.deSerialize(data), 
            name : identifier.deSerialize(data),
            type_args : @[]
        )
        let argsLen = deSerializeUleb128(data)
        for _ in 0..<argsLen:

            result.type_args.add deSerialize(data)

    of 8:

        return TypeTags(`type` : U16)

    of 9:

        return TypeTags(`type` : U32)

    of 10:

        return TypeTags(`type` : U256)

    else:

        raise newException(ValueError, "Invalid variant " & $variant)

proc parseHook*(s : string, i : var int, v : var TypeTags) =

    let s = s.strip()
    if not match(s, re"^(bool|u8|u64|u128|address|signer|vector<.+>|0x[0-9a-zA-Z:_<, >]+)$"):

        raise newException(ValueError, "Invalid type tag " & s)

    if s == "bool":

        v = TypeTags(`type` : Bool)

    elif s == "u8":

        v = TypeTags(`type` : U8)

    elif s == "u16":

        v = TypeTags(`type` : U16)

    elif s == "u32":

        v = TypeTags(`type` : U32)

    elif s == "u64":

        v = TypeTags(`type` : U64)

    elif s == "u128":

        v = TypeTags(`type` : U128)

    elif s == "u256":

        v = TypeTags(`type` : U256)

    elif s == "address":

        v = TypeTags(`type` : Addr)

    elif s == "signer":

        v = TypeTags(`type` : Signer)

    elif s[0..5] == "vector":
        
        let child = s[5..^1]
        v = TypeTags(`type` : Vector)
        v.childtype[] = fromJson(child[1..^2], TypeTags)

    elif match(s, re"^.*(::).*(::).*"): ## if it's a struct
        
        let argsPos = find(s, re"(<).*(>)")
        var
            ogStruct : string
            structArgs : string
        
        if argsPos != -1:

            structArgs = s[argsPos + 1..^2]
            ogStruct = s[0..argsPos - 1]

        else:

            ogStruct = s
        
        let parts = ogStruct.split("::")
        v = TypeTags(
            `type` : Struct,
            address : newAddress(parts[0]),
            module : newIdentifier(parts[1]),
            name : newIdentifier(parts[2]),
            type_args : @[]
        )
        if len(structArgs) > 0:

            for arg in structArgs.split(","):

                v.type_args.add fromJson(arg.strip(), TypeTags)

    else:

        raise newException(ValueError, "Invalid type tag " & s)

proc dumpHook*(s : var string, v : TypeTags) =

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
        
        s = fmt"vector<toJson(v.childtype[])>"

    of Struct:

        s = fmt"{v.address}::{v.module}::{v.name}<"
        let argsLen = len(v.type_args)
        if argsLen != 0:

            for pos in 0..<argsLen:

                s.add toJson(v.type_args[pos])
                if pos != argsLen - 1:

                    s.add ", "

        s.add ">"

when isMainModule:
    
    let struct = fromJson("0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>", TypeTags)
    echo toJson(struct)
    echo serialize(struct)

