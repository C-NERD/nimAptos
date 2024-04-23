from std / json import JsonNode
import resourcetypes

type

    WriteSetType* = enum

        ScriptWriteSetType = "script_write_set"
        DirectWriteSetType = "direct_write_set"

    WriteSet* = object

        case `type`* : WriteSetType
        of ScriptWriteSetType:

            execute_as* : string
            script* : tuple[code : MoveScriptBytecode, type_arguments, arguments : seq[string]]

        of DirectWriteSetType:

            changes* : seq[JsonNode] ## seq of Change
            events* : seq[JsonNode]  ## seq of Event
