import pkg / [bcs]

type
    
    Identifier* = object

        value : string

proc `$`*(data : Identifier) : string = data.value

proc newIdentifier*(data : string) : Identifier = Identifier(value : data)

proc serialize*(data : Identifier) : HexString = serializeStr(data.value)

proc deSerialize*(data : var HexString): Identifier = Identifier(value : deSerializeStr(data))
