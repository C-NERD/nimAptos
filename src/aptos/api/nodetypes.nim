#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementation for aptos node types

from std / strutils import removePrefix, removeSuffix, strip, split, parseUInt
from std / json import JsonNode
from std / options import isNone, Option

from pkg / jsony import toJson

type

    Error* = object

        message, error_code : string
        vm_error_code : int

    AccountData* = object
        
        sequence_number : uint64
        authentication_key : string
     
    ViewRequest*[T : tuple] = object

        function* : string
        type_arguments* : seq[string]
        arguments* : Option[T] ## serialize tuple to json as an array

    LedgerInfo* = object

        chain_id* : uint8
        epoch*, ledger_version*, oldest_ledger_version*, ledger_timestamp*, node_role*, oldest_block_height*, block_height*, git_hash* : string

    Block* = object

        block_height*, block_hash*, block_timestamp*, first_version*, last_version* : string
        transactions* : JsonNode

proc parseHook*(s : string, i : var int, v : var AccountData) =

    ## separate fields
    var data = s
    data.removePrefix("{")
    data.removeSuffix("}")
    data = data.strip()
    
    ## extract values from fields
    let fields = data.split(",")
    var 
        sequence_number = fields[0].strip().split(":")[1].strip()
        authentication_key = fields[1].strip().split(":")[1].strip()
    
    ## sanitize values
    sequence_number.removePrefix("\"")
    sequence_number.removeSuffix("\"")
    authentication_key.removePrefix("\"")
    authentication_key.removeSuffix("\"")
    
    ## create new object
    v = AccountData(
        sequence_number : uint64(parseUInt(sequence_number)),
        authentication_key : authentication_key
    )

proc dumpHook*(s : var string, v : ViewRequest) =

    s.add "{\"function\" : \"" & v.function & "\","
    s.add "\"type_arguments\" : " & toJson(v.type_arguments) & ","
    if v.arguments.isNone():

        s.add "\"arguments\" : []}"

    else:

        s.add "\"arguments\" : " & toJson(v.arguments) & "}"
 
