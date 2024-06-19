## std imports
#import std / [jsonutils, json]
from std / strutils import toHex, fromHex

## third party imports
import pkg / [bcs]

type

    SinglePubKey* = HexString

    MultiPubKey* = object
        
        keys : seq[SinglePubKey]
        threshold : uint

const 
    PUBLIC_KEY_BYTE_LEN = 32
    PUBLIC_KEY_HEX_LEN = PUBLIC_KEY_BYTE_LEN * 2

## util procs
proc initSinglePubKey*(key : HexString) : SinglePubKey = SinglePubKey(key)

proc initMultiPubKey*(keys : seq[SinglePubKey], threshold : range[0..31]) : MultiPubKey = 

    return MultiPubKey(
        keys : keys,
        threshold : uint(threshold)
    )

proc getKeys*(keys : MultiPubKey) : seq[SinglePubKey] = keys.keys

proc getThreshold*(keys : MultiPubKey) : uint = keys.threshold

## serialization procs
proc serialize*(data : SinglePubKey) : HexString =

    for val in serializeUleb128(uint32(byteLen(data))):

        result.add bcs.serialize[uint8](val)

    result.add data

proc serialize*(data : MultiPubKey) : HexString =
    
    var bcsResult : HexString
    for pos in 0..<len(data.keys):

        bcsResult.add data.keys[pos]

    bcsResult.add toHex(data.threshold, 2)
    result = bcs.serialize(bcsResult)

template deSerializeSinglePubKey(data : var HexString, key : var SinglePubKey) : untyped =

    let byteLen = deSerializeUleb128(data)
    key.add data[0..((byteLen * 2) - 1)]
    data = data[(byteLen * 2)..^1]

template deSerializeMultiPubKey(data : var HexString, keys : var MultiPubKey) : untyped =
     
    keys.threshold = fromHex[int]($data[^2..^1])
    data = data[0..^3]
    var hexData = bcs.deSerialize[HexString](data)
    while true:
        
        keys.keys.add initSinglePubKey(hexData[0..PUBLIC_KEY_HEX_LEN - 1])
        if len(hexData) <= 0:

            break

        hexData = hexData[PUBLIC_KEY_HEX_LEN..^1]

proc deSerialize*[T : SinglePubKey | MultiPubKey](data : var HexString) : T =

    when T is SinglePubKey:

        deSerializeSinglePubKey(data, result)

    elif T is MultiPubKey:

        deSerializeMultiPubKey(data, result)

