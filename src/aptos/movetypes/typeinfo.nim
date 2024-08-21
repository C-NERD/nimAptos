#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementation of move typeinfo

import pkg / [bcs]
import address

type

    TypeInfo*[T] = object

        account_address: Address
        module_name, struct_name: string
        data: T

proc initTypeInfo*[T](account_address: Address, module_name,
        struct_name: string, data: T): TypeInfo[T] =

    return TypeInfo[T](
        account_address: account_address,
        module_name: module_name,
        struct_name: struct_name,
        data: data
    )

proc toBcsHook*[T](data: TypeInfo[T], output: var HexString) =

    toBcsHook(data.account_address, output)
    output.add serialize(data.module_name)
    output.add serialize(data.struct_name)
    output.add serialize(data.data)

proc fromBcsHook*[T](data: var HexString, output: var TypeInfo[T]) =

    fromBcsHook(data, output.account_address)
    output.module_name = deSerialize[string](data)
    output.struct_name = deSerialize[string](data)
    output.data = deSerialize[typeof(output.data)](data)
