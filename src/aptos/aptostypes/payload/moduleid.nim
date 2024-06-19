#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementation for entryfunction payload moduleid

from std / strformat import fmt
from std / strutils import split, removePrefix, align
import pkg / [bcs]
import ../../movetypes/address

type

    ModuleId* = object

        address : Address
        name : string

converter `$`*(data : ModuleId) : string = fmt"{data.address}::{data.name}"

converter newModuleId*(data : string) : ModuleId = 

    let parts = data.split("::")
    var address = parts[0]
    address.removePrefix("0x")

    ## pad address
    let count = 65 - len(address)
    if count > 0:

        address = "0x" & align(address, count, '0')

    return ModuleId(
        address : initAddress(address),
        name : parts[1]
    )

proc serialize*(data : ModuleId) : HexString =

    result.add serialize(data.address)
    result.add serializeStr(data.name)

proc deSerialize*(data : var HexString) : ModuleId =

    return ModuleId(
        address : address.deSerialize(data),
        name : deSerializeStr(data)
    )

