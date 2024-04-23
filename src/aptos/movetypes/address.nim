from std / strutils import removePrefix, align, HexDigits
#from std / strformat import fmt

import pkg / [bcs, jsony]

type

    Address* = array[64, char]

func `$`*(x : Address) : string =

    for each in x:

        result.add each

    result = "0x" & result

proc isValidAddress*(data : string) : bool =

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

proc newAddress*(data : string) : Address =
    ## data should be a valid hex string
    
    var data = data
    removePrefix(data, "0x")

    assert isValidAddress(data), "Invalid address " & data
    
    data = align(data, 64, '0')
    for pos in 0..<len(result):

        result[pos] = data[pos]

proc serialize*(data : Address) : HexString =
    
    result.add fromString($data)

proc deSerialize*(data : var HexString) : Address =
    
    let len = deSerializeUleb128(data)
    result = newAddress($(data[0..63]))
    if len(data) > 64:

        data = data[64..^1]

    else:

        data = fromString("")

proc dumpHook*(s : var string, v : Address) = s.add("\"" & $v & "\"")

proc parseHook*(s : string, i : var int, v : var Address) =

    var str: string
    parseHook(s, i, str)

    v = newAddress(str)

