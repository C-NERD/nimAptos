import pkg / [bcs]
import address

type

    TypeInfo*[T] = object

        account_address : Address
        module_name, struct_name : string
        data : T

proc initTypeInfo*[T](account_address : Address, module_name, struct_name : string, data : T) : TypeInfo[T] =

    return TypeInfo[T](
        account_address : account_address,
        module_name : module_name,
        struct_name : struct_name,
        data : data
    )

proc serialize*[T](data : TypeInfo[T], data_serialize : proc(x : T) : HexString,) : HexString =

    result.add serialize(data.account_address)
    result.add bcs.serialize(data.module_name)
    result.add bcs.serialize(data.struct_name)
    result.add data_serialize(data.data)

proc deSerialize*[T](data : var HexString, data_deSerialize : proc(x : var HexString) : T,) : TypeInfo[T] =

    result.account_address = address.deSerialize(data)
    result.module_name = bcs.deSerialize[string](data)
    result.struct_name = bcs.deSerialize[string](data)
    result.data = data_deSerialize(data)
