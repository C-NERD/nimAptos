#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#
## implementation for move lang address type

import std / [json]
from std / strutils import removePrefix, align, HexDigits

import pkg / [bcs]

type

    Address* = object

        val: array[64, char]

func `$`*(x: Address): string =

    for each in x.val:

        result.add each

    result = "0x" & result

proc isValidAddress*(data: string): bool =

    let dataLen = len(data)
    if dataLen > 2 and (dataLen mod 2) != 0:

        return false

    elif dataLen > 64: ## address should not be more than string size 32 and hex size 64

        return false

    ## verify that address is valid hex
    for each in data:

        if each notin HexDigits:

            return false

    return true

proc initAddress*(data: string): Address =
    ## data should be a valid hex string

    var data = data
    removePrefix(data, "0x")

    data = align(data, 64, '0')
    assert isValidAddress(data), "Invalid address " & data

    for pos in 0..<len(result.val):

        result.val[pos] = data[pos]

proc toBcsHook*(data: Address, output: var HexString) =

    output.add fromString($data)

proc fromBcsHook*(data: var HexString, output: var Address) =

    output = initAddress($(data[0..63]))
    if len(data) > 64:

        data = data[64..^1]

    else:

        data = fromString("")

proc toJsonHook*(v: Address): JsonNode = %($v)

proc fromJsonHook*(v: var Address, s: JsonNode) = v = initAddress(getStr(s))

