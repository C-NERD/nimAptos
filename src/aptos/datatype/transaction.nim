import std / [json]
import pkg / [jsony]
import signature, payload

type

    RawTransaction* = ref object of RootObj ## root of transaction object for sending transactions
        
        chain_id* : int8
        sender*, sequence_number*, max_gas_amount*, gas_unit_price*, expiration_timestamp_secs* : string
        payload* : Payload

    SignTransaction* = ref object of RawTransaction ## raw transaction with signature

        signature* : Signature

    SubmittedTransaction* = ref object of SignTransaction ## transaction object returned from submitTransaction proc

        hash* : string

    MultiAgentRawTransaction* = ref object of RawTransaction ## raw transaction for signing with node

        secondary_signers* : seq[string]

proc parseHook*(s : string, i : var int, v : var SubmittedTransaction) =

    var jsonTransaction : JsonNode
    parseHook(s, i, jsonTransaction)
    v = SubmittedTransaction(
        hash : getStr(jsonTransaction["hash"]),
        sender : getStr(jsonTransaction["sender"]),
        sequence_number : getStr(jsonTransaction["sequence_number"]),
        max_gas_amount : getStr(jsonTransaction["max_gas_amount"]),
        gas_unit_price : getStr(jsonTransaction["gas_unit_price"]),
        expiration_timestamp_secs : getStr(jsonTransaction["expiration_timestamp_secs"]),
        signature : ($jsonTransaction["signature"]).fromJson(Signature),
        payload : ($jsonTransaction["payload"]).fromJson(Payload)
    )

proc dumpHook*(s : var string, v : RawTransaction) =
    
    s.add "{\"chain_id\":" & $v.chain_id & ","
    s.add "\"sender\":\"" & v.sender & "\","
    s.add "\"sequence_number\":\"" & v.sequence_number & "\","
    s.add "\"max_gas_amount\":\"" & v.max_gas_amount & "\","
    s.add "\"gas_unit_price\":\"" & v.gas_unit_price & "\","
    s.add "\"expiration_timestamp_secs\":\"" & v.expiration_timestamp_secs & "\","
    s.add "\"payload\":" & v.payload.toJson() & "}"

proc dumpHook*(s : var string, v : SignTransaction) =
    
    s.add "{\"chain_id\":" & $v.chain_id & ","
    s.add "\"sender\":\"" & v.sender & "\","
    s.add "\"sequence_number\":\"" & v.sequence_number & "\","
    s.add "\"max_gas_amount\":\"" & v.max_gas_amount & "\","
    s.add "\"gas_unit_price\":\"" & v.gas_unit_price & "\","
    s.add "\"expiration_timestamp_secs\":\"" & v.expiration_timestamp_secs & "\","
    s.add "\"payload\":" & v.payload.toJson() & ","
    s.add "\"signature\":" & v.signature.toJson() & "}"

proc dumpHook*(s : var string, v : SubmittedTransaction) =
    
    s.add "{\"hash\":\"" & v.hash & "\","
    s.add "\"sender\":\"" & v.sender & "\","
    s.add "\"sequence_number\":\"" & v.sequence_number & "\","
    s.add "\"max_gas_amount\":\"" & v.max_gas_amount & "\","
    s.add "\"gas_unit_price\":\"" & v.gas_unit_price & "\","
    s.add "\"expiration_timestamp_secs\":\"" & v.expiration_timestamp_secs & "\","
    s.add "\"payload\":" & v.payload.toJson() & ","
    s.add "\"signature\":" & v.signature.toJson() & "}"

proc dumpHook*(s : var string, v : MultiAgentRawTransaction) =
    
    s.add "{\"chain_id\":" & $v.chain_id & ","
    s.add "\"sender\":\"" & v.sender & "\","
    s.add "\"sequence_number\":\"" & v.sequence_number & "\","
    s.add "\"max_gas_amount\":\"" & v.max_gas_amount & "\","
    s.add "\"gas_unit_price\":\"" & v.gas_unit_price & "\","
    s.add "\"expiration_timestamp_secs\":\"" & v.expiration_timestamp_secs & "\","
    s.add "\"payload\":" & v.payload.toJson() & ","
    s.add "\"secondary_signers\":" & v.secondary_signers.toJson() & "}"

proc `$`*(data : RawTransaction) : string = toJson(data)

proc `$`*(data : SignTransaction) : string = toJson(data)

proc `$`*(data : MultiAgentRawTransaction) : string = toJson(data)

proc `$`*(data : SubmittedTransaction) : string = toJson(data)

converter toSignTransaction*[T : RawTransaction | MultiAgentRawTransaction](txn : T) : SignTransaction =

    return SignTransaction(
        chain_id : txn.chain_id,
        sender : txn.sender, 
        sequence_number : txn.sequence_number, 
        max_gas_amount : txn.max_gas_amount, 
        gas_unit_price : txn.gas_unit_price, 
        expiration_timestamp_secs : txn.expiration_timestamp_secs,
        payload : txn.payload
    )

converter toMultiAgentRawTransaction*[T : RawTransaction | SignTransaction](txn : T) : MultiAgentRawTransaction =

    return MultiAgentRawTransaction(
        chain_id : txn.chain_id,
        sender : txn.sender, 
        sequence_number : txn.sequence_number, 
        max_gas_amount : txn.max_gas_amount, 
        gas_unit_price : txn.gas_unit_price, 
        expiration_timestamp_secs : txn.expiration_timestamp_secs,
        payload : txn.payload
    )
