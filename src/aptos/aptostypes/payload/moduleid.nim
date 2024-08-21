#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementation for entryfunction payload moduleid

from std / strformat import fmt
from std / strutils import split, removePrefix, align

## third party imports
import pkg / [bcs]

## project imports
import ../../movetypes/address
#import ../../errors

type

    ModuleId* = object

        address: Address
        name: string

converter `$`*(data: ModuleId): string = fmt"{data.address}::{data.name}"

converter newModuleId*(data: string): ModuleId =

    let parts = data.split("::")
    var address = parts[0]
    address.removePrefix("0x")

    ## pad address
    let count = 65 - len(address)
    if count > 0:

        address = "0x" & align(address, count, '0')

    return ModuleId(
        address: initAddress(address),
        name: parts[1]
    )

proc toBcsHook*(data: ModuleId, output: var HexString) =

    toBcsHook(data.address, output)
    output.add serializeStr(data.name)

proc fromBcsHook*(data: var HexString, output: var ModuleId) =

    fromBcsHook(data, output.address)
    output.name = deSerializeStr(data)

