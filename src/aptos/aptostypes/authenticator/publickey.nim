#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementation of aptos publickey types

## std imports
#import std / [jsonutils, json]
from std / strutils import toHex, fromHex

## third party imports
import pkg / [bcs]

type

    SinglePubKey* = HexString

    MultiPubKey* = object

        keys: seq[SinglePubKey]
        threshold: uint

const
    PUBLIC_KEY_BYTE_LEN = 32
    PUBLIC_KEY_HEX_LEN = PUBLIC_KEY_BYTE_LEN * 2

## util procs
proc initSinglePubKey*(key: HexString): SinglePubKey = SinglePubKey(key)

proc initMultiPubKey*(keys: seq[SinglePubKey], threshold: range[
        0..31]): MultiPubKey =

    return MultiPubKey(
        keys: keys,
        threshold: uint(threshold)
    )

proc getKeys*(keys: MultiPubKey): seq[SinglePubKey] = keys.keys

proc getThreshold*(keys: MultiPubKey): uint = keys.threshold

## serialization procs
proc toBcsHook*(data: SinglePubKey, output: var HexString) =

    for val in serializeUleb128(uint32(byteLen(data))):

        output.add serialize(val)

    output.add data

proc toBcsHook*(data: MultiPubKey, output: var HexString) =

    var bcsResult: HexString
    for pos in 0..<len(data.keys):

        bcsResult.add data.keys[pos]

    bcsResult.add toHex(data.threshold, 2)
    output.add serialize(bcsResult)

proc fromBcsHook*(data: var HexString,
        output: var SinglePubKey) =

    let byteLen = deSerializeUleb128(data)
    output = data[0..((byteLen * 2) - 1)]
    data = data[(byteLen * 2)..^1]

proc fromBcsHook*(data: var HexString,
        output: var MultiPubKey) =

    output.threshold = fromHex[uint]($data[^2..^1])
    data = data[0..^3]
    var hexData = deSerialize[HexString](data)
    while true:

        output.keys.add initSinglePubKey(hexData[0..PUBLIC_KEY_HEX_LEN - 1])
        if len(hexData) <= 0:

            break

        hexData = hexData[PUBLIC_KEY_HEX_LEN..^1]

