#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#
## implementation for move lang identifiers

import pkg / [bcs]

type

    Identifier* = object

        value: string

proc `$`*(data: Identifier): string = data.value

proc initIdentifier*(data: string): Identifier = Identifier(value: data)

proc toBcsHook*(data: Identifier, output: var HexString) = output.add serializeStr(data.value)

proc fromBcsHook*(data: var HexString, output: var Identifier) = output = Identifier(
        value: deSerializeStr(data))
