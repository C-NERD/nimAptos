#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementation of aptos signature types

## std imports
import std / [bitops]
from std / strformat import fmt
from std / strutils import toHex

## third party imports
import pkg / [bcs]

type

    SingleEd25519Signature* = HexString

    MultiEd25519Signature* = object

        signatures: seq[SingleEd25519Signature]
        bitmap: HexString

const
    MAX_SIGNATURES_SUPPORTED* = 32
    SINGLE_ED25519_SIG_BYTE_LENGTH* = 32
    SINGLE_ED25519_SIG_HEX_LENGTH* = SINGLE_ED25519_SIG_BYTE_LENGTH * 2
    BITMAP_BYTE_LENGTH* = 4
    BITMAP_HEX_LENGTH* = 8
    SINGLE_ED25519_SIG_ENUM*: uint8 = 0
    MULTI_ED25519_SIG_ENUM*: uint8 = 1

## util procs
proc createBitMap*(bits: seq[int]): HexString =

    var
        dupCheck: seq[int]
        bitMap: uint32 = 0
    for pos in 0..<len(bits):

        if bits[pos] >= MAX_SIGNATURES_SUPPORTED:

            raise newException(CatchableError,
                    fmt"signature cannot be larger than {MAX_SIGNATURES_SUPPORTED}")

        elif bits[pos] in dupCheck:

            raise newException(CatchableError, "duplicate bits detected")

        elif pos > 0:

            if bits[pos] <= bits[pos - 1]:

                raise newException(CatchableError, "the bits should be sorted in ascending order")

        dupCheck.add bits[pos]

        #[let byteOffset = int(bits[pos] div 8)
        result[byteOffset] = bitor(result[byteOffset], (firstBitInByte shr (bits[pos] mod 8)))]#

        let shift = 31 - pos
        bitMap = bitor(bitMap, uint32(1 shl shift))

    return fromString(toHex(bitMap))

proc initSingleSignature*(signature: HexString): SingleEd25519Signature = SingleEd25519Signature(signature)

proc initMultiSignature*(signatures: seq[SingleEd25519Signature],
        positions: seq[int]): MultiEd25519Signature =

    return MultiEd25519Signature(
        signatures: signatures,
        bitmap: createBitMap(positions)
    )

proc initMultiSignature*(signatures: seq[SingleEd25519Signature],
        bitMap: HexString): MultiEd25519Signature =

    if byteLen(bitMap) != BITMAP_BYTE_LENGTH:

        raise newException(RangeDefect, fmt"invalid bitMap {bitMap}")

    return MultiEd25519Signature(
        signatures: signatures,
        bitmap: bitMap
    )

proc getSignatures*(signatures: MultiEd25519Signature): seq[
        SingleEd25519Signature] = signatures.signatures

proc getBitmap*(signatures: MultiEd25519Signature): HexString = signatures.bitmap

## serialization procs
proc serialize*(data: SingleEd25519Signature): HexString =

    for val in serializeUleb128(uint32(byteLen(data))):

        result.add bcs.serialize[uint8](val)

    result.add data

proc serialize*(data: MultiEd25519Signature): HexString =

    var bcsResult: HexString
    for signature in data.signatures:

        bcsResult.add signature

    bcsResult.add data.bitmap
    return bcsResult
    #result = bcs.serialize(bcsResult)

template deSerializeSingleEd25519Signature(data: var HexString,
        sig: var SingleEd25519Signature): untyped =

    let byteLen = deSerializeUleb128(data)
    sig.add data[0..((byteLen * 2) - 1)]
    data = data[(byteLen * 2)..^1]

template deSerializeMultiEd25519Signature(data: var HexString,
        sigs: var MultiEd25519Signature): untyped =

    #[sigs.bitmap = data[(len(data) - BITMAP_HEX_LENGTH)..^1]
    data = data[0..((len(data) - 1) - BITMAP_HEX_LENGTH)]
    var hexData = bcs.deSerialize[HexString](data)
    while true:

        sigs.signature.add initSingleSignature(hexData[0..SINGLE_ED25519_SIG_HEX_LENGTH - 1])
        if len(hexData) <= 0:

            break

        hexData = hexData[SINGLE_ED25519_SIG_HEX_LENGTH..^1]]#

    {.fatal: "MultiEd25519Signature deSerialization is not implemented yet".}

proc deSerialize*[T: SingleEd25519Signature | MultiEd25519Signature](
    data: var HexString): T =

    when T is SingleEd25519Signature:

        deSerializeSingleEd25519Signature(data, result)

    elif T is MultiEd25519Signature:

        deSerializeMultiEd25519Signature(data, result)

