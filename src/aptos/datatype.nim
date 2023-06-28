#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## This module contains code for nim representation of
## easily serializable aptos types

## std imports
import std / [json, options]
from std / strutils import parseEnum

## nimble imports
import pkg / [jsony]

## package imports
import datatypeutils

type

    InvalidTransaction* = object of ValueError

    Error* = object

        message, error_code : string
        vm_error_code : int

    SignatureType* = enum

        SingleSignature = "ed25519_signature"
        MultiSignature = "multi_ed25519_signature"
        MultiAgentSignature = "multi_agent_signature"

    Signature* = object

        case `type`* : SignatureType
        of SingleSignature:

            public_key*, signature* : string

        of MultiSignature:

            public_keys*, signatures* : seq[string]
            bitmap* : string ## array of size 32 containing bits of signatures. 1 for Nth signature if present
            ## 0 for Nth signature if absent
            threshold* : int ## the minimum number of public keys required for this signature to be
            ## authorized

        of MultiAgentSignature:

            secondary_signer_addresses* : seq[string]
            sender* : ref Signature
            secondary_signers* : seq[Signature]

    PayloadType* = enum

        WriteSetPayload = "write_set_payload"
        EntryFunction = "entry_function_payload"
        ScriptPayload = "script_payload"
        ModuleBundle = "module_bundle_payload"
        Multisig = "multisig_payload"

    Payload* = object

        case `type`* : PayloadType
        of ModuleBundle:

            modules : seq[MoveModule]

        of Multisig:

            multisig_address : string
            transaction_payload : ref Payload ## only for EntryFunction payload type

        of EntryFunction:

            function* : string
            entry_type_arguments* : seq[string]
            entry_arguments* : seq[JsonNode]

        of ScriptPayload:

            code* : MoveScriptBytecode
            script_type_arguments* : seq[string]
            script_arguments* : seq[JsonNode]

        of WriteSetPayload:

            write_set : WriteSet
    
    ViewRequest* = object

        function* : string
        type_arguments* : seq[string]
        arguments* : seq[JsonNode]

    WriteSetType = enum

        ScriptWriteSetType = "script_write_set"
        DirectWriteSetType = "direct_write_set"

    WriteSet = object

        case `type` : WriteSetType
        of ScriptWriteSetType:

            execute_as : string
            script : tuple[code : MoveScriptBytecode, type_arguments, arguments : seq[string]]

        of DirectWriteSetType:

            changes : seq[Change]
            events : seq[Event]

    ChangeType = enum

        DeleteModule = "delete_module"
        DeleteResource = "delete_resource"
        DeleteTableItem = "delete_table_item"
        WriteModule = "write_module"
        WriteResource = "write_resource"
        WriteTableItem = "write_table_item"

    Change = object

        state_key_hash : string
        case `type` : ChangeType
        of DeleteModule:

            delete_module_address, module : string

        of DeleteResource:

            delete_resource_address, resource : string
        
        of WriteModule:

            write_module_address : string
            write_module_data : MoveModuleByteCode
        
        of WriteResource:

            write_resource_address : string
            write_resource_data : MoveResource

        of DeleteTableItem:

            delete_handle, delete_key : string
            delete_table_data : tuple[key, key_type : string]

        of WriteTableItem:

            write_handle, write_key, value : string
            write_table_data : Option[tuple[key, key_type, value, value_type : string]]

    Event* = object

        `type`*, version*, sequence_number* : string
        guid* : tuple[creation_number, account_address : string]
        data* : tuple[
            epoch, hash, height, previous_block_votes_bitvec, proposer, round, time_microseconds : string, 
            failed_proposer_indices : seq[int]
        ]

    TransactionType* = enum

        PendingTransaction = "pending_transaction"
        UserTransaction = "user_transaction"
        GenesisTransaction = "genesis_transaction"
        BlockMetaTransaction = "block_metadata_transaction"
        StateCheckPointTransaction = "state_checkpoint_transaction"

    Transaction* = object ## transaction object to be used to parse any transaction received

        hash* : string
        case `type`* : TransactionType

        of PendingTransaction:

            pending_sender*, pending_sequence_number*, pending_max_gas_amount*, pending_gas_unit_price* : string
            pending_expiration_timestamp_secs* : string
            pending_payload* : Payload
            pending_signature* : Signature

        of UserTransaction:

            user_sender*, user_sequence_number*, user_max_gas_amount*, user_gas_unit_price*, user_expiration_timestamp_secs* : string
            user_version*, user_state_change_hash*, user_event_root_hash*, user_state_checkpoint_hash*, user_gas_used* : string 
            user_vm_status*, user_accumulator_root_hash*, user_timestamp* : string
            user_success* : bool
            user_payload* : Payload
            user_signature* : Signature
            user_changes* : seq[Change]
            user_events* : seq[Event]

        of GenesisTransaction:

            genesis_version*, genesis_state_change_hash*, genesis_event_root_hash*, genesis_state_checkpoint_hash* : string 
            genesis_gas_used*, genesis_vm_status*, genesis_accumulator_root_hash*, genesis_timestamp* : string
            genesis_success* : bool
            genesis_payload* : Payload ## only WriteSetPayload payload type
            genesis_changes* : seq[Change]
            genesis_events* : seq[Event]
        
        of BlockMetaTransaction:

            block_version*, block_state_change_hash*, block_event_root_hash*, block_state_checkpoint_hash*, block_gas_used* : string 
            block_vm_status*, block_accumulator_root_hash*, block_timestamp* : string
            block_success* : bool
            id, epoch, round, proposer* : string
            previous_block_votes_bitvec* : seq[uint8]
            failed_proposer_indices* : seq[int32]
            block_changes* : seq[Change]
            block_events* : seq[Event]
        
        of StateCheckPointTransaction:

            state_version*, state_state_change_hash*, state_event_root_hash*, state_state_checkpoint_hash*, state_gas_used* : string 
            state_vm_status*, state_accumulator_root_hash*, state_timestamp* : string
            state_success* : bool
            state_changes* : seq[Change]

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

    Block* = object

        block_height*, block_hash*, block_timestamp*, first_version*, last_version* : string
        transactions* : seq[Transaction]

    LedgerInfo* = object

        chain_id* : int8
        epoch*, ledger_version*, oldest_ledger_version*, ledger_timestamp*, node_role*, oldest_block_height*, block_height*, git_hash* : string

    CapabilityOffer = object

        `for` : tuple[vec : seq[string]]

    ResourceEvent = object

        counter : string
        guid : tuple[id : tuple[`addr`, creation_num : string]]
    
    AccountResource* = object

        authentication_key*, sequence_number*, guid_creation_num : string
        coin_register_events, key_rotation_events : ResourceEvent
        rotation_capability_offer, signer_capability_offer : CapabilityOffer
    
    MultiSigAccountResource* = object

        add_owners_events*, create_transaction_events*, execute_rejected_transaction_events*, execute_transaction_events* : ResourceEvent
        metadata_updated_events*, remove_owners_event*, transaction_execution_failed_events*, update_signature_required_events*, vote_events* : ResourceEvent
        last_executed_sequence_number*, next_sequence_number*, num_signatures_required* : string
        metadata* : tuple[data : seq[JsonNode]]
        owners* : seq[string]
        signer_cap* : tuple[vec : seq[JsonNode]]
        transactions* : tuple[handle : string]

    CoinResource* = object

        frozen : bool
        coin* : tuple[value : string]
        deposit_events, withdraw_events : ResourceEvent

    Struct* = object

        name : string
        is_native : bool
        abilities : seq[string]
        generic_type_params : seq[tuple[constraints : seq[string]]]
        fields : seq[tuple[name, `type` : string]]

    MoveFunction* = object

        name, visibility : string
        is_entry : bool
        generic_type_params : seq[tuple[constraints : seq[string]]]
        params : seq[string]
        `return` : seq[string]

    MoveModule* = object

        address, name : string
        friends : seq[string]
        exposed_functions : seq[MoveFunction]
        structs : seq[Struct]

    MoveModuleByteCode* = object

        bytecode : string
        abi : MoveModule

    ResourceType* = enum
        ## TODO :: add more resource type

        AccountResourceType = "0x1::account::Account"
        MultiSigAccountResourceType = "0x1::multisig_account::MultisigAccount"
        AptCoinResourceType = "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>"

    MoveResource* = object

        case `type`* : ResourceType
        of AccountResourceType:

            acct_data* : AccountResource

        of AptCoinResourceType:

            coin_data* : CoinResource

        of MultiSigAccountResourceType:

            multi_acct_data* : MultiSigAccountResource

    MoveScriptBytecode* = object

        bytecode : string
        abi : MoveFunction

proc parseHook*(s : string, i : var int, v : var MoveResource) =

    var jsonResource : JsonNode
    parseHook(s, i, jsonResource)
    case getStr(jsonResource["type"])

    of $AccountResourceType:

        v = MoveResource(
            `type` : AccountResourceType,
            acct_data : ($jsonResource["data"]).fromJson(AccountResource)
        )

    of $AptCoinResourceType:

        v = MoveResource(
            `type` : AptCoinResourceType,
            coin_data : ($jsonResource["data"]).fromJson(CoinResource)
        )

    of $MultiSigAccountResourceType:

        v = MoveResource(
            `type` : MultiSigAccountResourceType,
            multi_acct_data : ($jsonResource["data"]).fromJson(MultiSigAccountResource)
        )

proc parseHook*(s : string, i : var int, v : var Payload) =

    var jsonPayload : JsonNode
    parseHook(s, i, jsonPayload)

    let payloadType = parseEnum[PayloadType](getStr(jsonPayload["type"]))
    case payloadType

    of EntryFunction:

        v = Payload(
            `type` : EntryFunction,
            function : getStr(jsonPayload["function"]),
            entry_type_arguments : jsonPayload["type_arguments"].to(seq[string]),
            entry_arguments : getElems(jsonPayload["arguments"])
        )

    of ScriptPayload:

        v = Payload(
            `type` : ScriptPayload,
            code : jsonPayload["code"].to(MoveScriptBytecode),
            script_type_arguments : jsonPayload["type_arguments"].to(seq[string]),
            script_arguments : getElems(jsonPayload["arguments"])
        )

    of Multisig:

        v = Payload(
            `type` : payloadType,
            multisig_address : getStr(jsonPayload["multisig_address"]),
            transaction_payload : ($jsonPayload["transaction_payload"]).fromJson(ref Payload)
        )

    of ModuleBundle:

        v = Payload(
            `type` : payloadType,
            modules : ($jsonPayload["modules"]).fromJson(seq[MoveModule])
        )

    of WriteSetPayload:

        v = Payload(
            `type` : payloadType,
            write_set : ($jsonPayload["write_set"]).fromJson(WriteSet)
        )

proc parseHook*(s : string, i : var int, v : var Change) =

    var jsonChange : JsonNode
    parseHook(s, i, jsonChange)

    let changeType = parseEnum[ChangeType](getStr(jsonChange["type"]))
    case changeType

    of DeleteModule:

        v = Change(
            `type` : DeleteModule,
            state_key_hash : getStr(jsonChange["state_key_hash"]),
            delete_module_address : getStr(jsonChange["address"]),
            module : getStr(jsonChange["module"])
        )

    of DeleteResource:

        v = Change(
            `type` : DeleteResource,
            state_key_hash : getStr(jsonChange["state_key_hash"]),
            delete_resource_address : getStr(jsonChange["address"]),
            resource : getStr(jsonChange["resource"])
        )

    of DeleteTableItem:

        v = Change(
            `type` : DeleteTableItem,
            state_key_hash : getStr(jsonChange["state_key_hash"]),
            delete_handle : getStr(jsonChange["handle"]),
            delete_key : getStr(jsonChange["key"]),
            delete_table_data : fromJson($jsonChange["data"], tuple[key, key_type : string])
        )

    of WriteModule:

        v = Change(
            `type` : WriteModule,
            state_key_hash : getStr(jsonChange["state_key_hash"]),
            write_module_address : getStr(jsonChange["address"]),
            write_module_data : fromJson($jsonChange["data"], MoveModuleByteCode)
        )

    of WriteResource:

        v = Change(
            `type` : WriteResource,
            state_key_hash : getStr(jsonChange["state_key_hash"]),
            write_resource_address : getStr(jsonChange["address"]),
            write_resource_data : fromJson($jsonChange["data"], MoveResource)
        )

    of WriteTableItem:

        v = Change(
            `type` : WriteTableItem,
            state_key_hash : getStr(jsonChange["state_key_hash"]),
            write_handle : getStr(jsonChange["handle"]),
            write_key : getStr(jsonChange["key"]),
            value : getStr(jsonChange["value"]),
            write_table_data : fromJson($jsonChange["data"], Option[tuple[key, key_type, value, value_type : string]])
        )

proc parseTransaction(jsonTransaction : JsonNode, v : var Transaction) =
    
    let transactionType : TransactionType = parseEnum[TransactionType](getStr(jsonTransaction["type"]))
    case transactionType

    of PendingTransaction:

        v = Transaction(
            `type` : PendingTransaction,
            hash : getStr(jsonTransaction["hash"]),
            pending_sender : getStr(jsonTransaction["sender"]),
            pending_sequence_number : getStr(jsonTransaction["sequence_number"]),
            pending_max_gas_amount : getStr(jsonTransaction["max_gas_amount"]),
            pending_gas_unit_price : getStr(jsonTransaction["gas_unit_price"]),
            pending_expiration_timestamp_secs : getStr(jsonTransaction["expiration_timestamp_secs"]),
            pending_signature : ($jsonTransaction["signature"]).fromJson(Signature),
            pending_payload : ($jsonTransaction["payload"]).fromJson(Payload)
        )

    of UserTransaction:

        v = Transaction(
            `type` : UserTransaction,
            hash : getStr(jsonTransaction["hash"]),
            user_sender : getStr(jsonTransaction["sender"]),
            user_sequence_number : getStr(jsonTransaction["sequence_number"]),
            user_max_gas_amount : getStr(jsonTransaction["max_gas_amount"]),
            user_gas_unit_price : getStr(jsonTransaction["gas_unit_price"]),
            user_expiration_timestamp_secs : getStr(jsonTransaction["expiration_timestamp_secs"]),
            user_version : getStr(jsonTransaction["version"]), 
            user_state_change_hash : getStr(jsonTransaction["state_change_hash"]), 
            user_event_root_hash : getStr(jsonTransaction["event_root_hash"]), 
            user_state_checkpoint_hash : getStr(jsonTransaction["state_checkpoint_hash"]), 
            user_success : getBool(jsonTransaction["success"]),
            user_gas_used : getStr(jsonTransaction["gas_used"]), 
            user_vm_status : getStr(jsonTransaction["vm_status"]), 
            user_accumulator_root_hash : getStr(jsonTransaction["accumulator_root_hash"]), 
            user_timestamp : getStr(jsonTransaction["timestamp"]),
            user_signature : ($jsonTransaction["signature"]).fromJson(Signature),
            user_payload : ($jsonTransaction["payload"]).fromJson(Payload),
            user_events : ($jsonTransaction["events"]).fromJson(seq[Event]),
            user_changes : ($jsonTransaction["changes"]).fromJson(seq[Change])
        )

    of GenesisTransaction:

        v = Transaction(
            `type` : GenesisTransaction,
            hash : getStr(jsonTransaction["hash"]),
            genesis_version : getStr(jsonTransaction["version"]), 
            genesis_state_change_hash : getStr(jsonTransaction["state_change_hash"]), 
            genesis_event_root_hash : getStr(jsonTransaction["event_root_hash"]), 
            genesis_state_checkpoint_hash : getStr(jsonTransaction["state_checkpoint_hash"]), 
            genesis_gas_used : getStr(jsonTransaction["gas_used"]), 
            genesis_vm_status : getStr(jsonTransaction["vm_status"]), 
            genesis_accumulator_root_hash : getStr(jsonTransaction["accumulator_root_hash"]), 
            genesis_success : getBool(jsonTransaction["success"]),
            genesis_timestamp : getStr(jsonTransaction["timestamp"]),
            genesis_payload : ($jsonTransaction["payload"]).fromJson(Payload),
            genesis_events : ($jsonTransaction["events"]).fromJson(seq[Event]),
            genesis_changes : ($jsonTransaction["changes"]).fromJson(seq[Change])
        )

    of BlockMetaTransaction:

        v = Transaction(
            `type` : BlockMetaTransaction,
            hash : getStr(jsonTransaction["hash"]),
            block_version : getStr(jsonTransaction["version"]), 
            block_state_change_hash : getStr(jsonTransaction["state_change_hash"]), 
            block_event_root_hash : getStr(jsonTransaction["event_root_hash"]), 
            block_state_checkpoint_hash : getStr(jsonTransaction["state_checkpoint_hash"]), 
            block_gas_used : getStr(jsonTransaction["gas_used"]), 
            block_vm_status : getStr(jsonTransaction["vm_status"]), 
            block_accumulator_root_hash : getStr(jsonTransaction["accumulator_root_hash"]), 
            block_timestamp : getStr(jsonTransaction["timestamp"]),
            block_success : getBool(jsonTransaction["success"]),
            id : getStr(jsonTransaction["id"]), 
            epoch : getStr(jsonTransaction["epoch"]), 
            round : getStr(jsonTransaction["round"]), 
            proposer : getStr(jsonTransaction["proposer"]),
            previous_block_votes_bitvec : ($jsonTransaction["previous_block_votes_bitvec"]).fromJson(seq[uint8]),
            failed_proposer_indices : ($jsonTransaction["failed_proposer_indices"]).fromJson(seq[int32]),
            block_events : ($jsonTransaction["events"]).fromJson(seq[Event]),
            block_changes : ($jsonTransaction["changes"]).fromJson(seq[Change])
        )

    of StateCheckPointTransaction:

        v = Transaction(
            `type` : StateCheckPointTransaction,
            hash : getStr(jsonTransaction["hash"]),
            state_version : getStr(jsonTransaction["version"]), 
            state_state_change_hash : getStr(jsonTransaction["state_change_hash"]), 
            state_event_root_hash : getStr(jsonTransaction["event_root_hash"]), 
            state_state_checkpoint_hash : getStr(jsonTransaction["state_checkpoint_hash"]), 
            state_gas_used : getStr(jsonTransaction["gas_used"]), 
            state_vm_status : getStr(jsonTransaction["vm_status"]), 
            state_accumulator_root_hash : getStr(jsonTransaction["accumulator_root_hash"]), 
            state_success : getBool(jsonTransaction["success"]),
            state_timestamp : getStr(jsonTransaction["timestamp"]),
            state_changes : ($jsonTransaction["changes"]).fromJson(seq[Change])
        )

proc parseHook*(s : string, i : var int, v : var Transaction) =

    var jsonTransaction : JsonNode
    parseHook(s, i, jsonTransaction)

    parseTransaction(jsonTransaction, v)

proc parseHook*(s : string, i : var int, v : var seq[Transaction]) =

    var jsonTransactions : JsonNode
    parseHook(s, i, jsonTransactions)

    let txnNum = len(jsonTransactions)
    v.setLen(txnNum)
    for pos in 0..<txnNum:

        parseTransaction(jsonTransactions[pos], v[pos])

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

proc dumpHook*(s : var string, v : MoveResource) =

    var data : string
    case v.`type`
    
    of AccountResourceType:

        data = toJson(v.acct_data)

    of AptCoinResourceType:

        data = toJson(v.coin_data)

    of MultiSigAccountResourceType:

        data = toJson(v.multi_acct_data)

    s = "{\"type\":\"" & $v.`type` & "\",\"data\":\"" & data & "\"}"

proc dumpHook*(s : var string, v : Payload) =

    case v.`type`

    of EntryFunction:

        s = (
            `type` : $v.`type`,
            function : v.function,
            type_arguments : v.entry_type_arguments,
            arguments : v.entry_arguments
        ).convertToJson().toJson()

    of ScriptPayload:

        s = (
            `type` : $v.`type`,
            code : v.code,
            type_arguments : v.script_type_arguments,
            arguments : v.script_arguments
        ).convertToJson().toJson()

    of Multisig:

        s = (
            `type` : $v.`type`,
            multisig_address : v.multisig_address ,
            transaction_payload : v.transaction_payload
        ).convertToJson().toJson()

    of ModuleBundle:

        s = (
            `type` : $v.`type`,
            modules : v.modules
        ).convertToJson().toJson()

    of WriteSetPayload:

        s = (
            `type` : v.`type`,
            write_set : v.write_set
        ).convertToJson().toJson()

proc dumpHook*(s : var string, v : Change) =

    case v.`type`

    of DeleteModule:

        s = (
            `type` : $v.`type`,
            state_key_hash : v.state_key_hash,
            address : v.delete_module_address,
            module : v.module,
        ).convertToJson().toJson()

    of DeleteResource:

        s = (
            `type` : $v.`type`,
            state_key_hash : v.state_key_hash,
            address : v.delete_resource_address,
            resource : v.resource
        ).convertToJson().toJson()

    of DeleteTableItem:

        s = (
            `type` : $v.`type`,
            state_key_hash : v.state_key_hash,
            handle : v.delete_handle,
            key : v.delete_key,
            data : v.delete_table_data
        ).convertToJson().toJson()

    of WriteModule:

        s = (
            `type` : $v.`type`,
            state_key_hash : v.state_key_hash,
            address : v.write_module_address,
            data : v.write_module_data
        ).convertToJson().toJson()

    of WriteResource:

        s = (
            `type` : $v.`type`,
            state_key_hash : v.state_key_hash,
            address : v.write_resource_address,
            data : v.write_resource_data
        ).convertToJson().toJson()

    of WriteTableItem:

        s = (
            `type` : $v.`type`,
            state_key_hash : v.state_key_hash,
            handle : v.write_handle,
            key : v.write_key,
            value : v.value,
            data : v.write_table_data
        ).convertToJson().toJson()

proc dumpHook*(s : var string, v : Transaction) =

    case v.`type`

    of PendingTransaction:

        s = (
            `type` : $v.`type`, 
            hash : v.hash,
            sender : v.pending_sender,
            sequence_number : v.pending_sequence_number,
            max_gas_amount : v.pending_max_gas_amount,
            gas_unit_price : v.pending_gas_unit_price,
            expiration_timestamp_secs : v.pending_expiration_timestamp_secs,
            payload : v.pending_payload,
            signature : v.pending_signature,
        ).convertToJson().toJson()

    of UserTransaction:

        s = (
            `type` : $v.`type`,
            hash : v.hash,
            sender : v.user_sender,
            sequence_number : v.user_sequence_number,
            max_gas_amount : v.user_max_gas_amount,
            gas_unit_price : v.user_gas_unit_price,
            expiration_timestamp_secs : v.user_expiration_timestamp_secs,
            version : v.user_version,
            state_change_hash : v.user_state_change_hash,
            event_root_hash : v.user_event_root_hash,
            state_checkpoint_hash : v.user_state_checkpoint_hash,
            gas_used : v.user_gas_used,
            vm_status : v.user_vm_status,
            accumulator_root_hash : v.user_accumulator_root_hash,
            timestamp : v.user_timestamp,
            success : v.user_success,
            payload : v.user_payload,
            signature : v.user_signature,
            changes : v.user_changes,
            events : v.user_events
        ).convertToJson().toJson()

    of GenesisTransaction:

        s = (
            `type` : $v.`type`, 
            hash : v.hash,
            version : v.genesis_version,
            state_change_hash : v.genesis_state_change_hash,
            event_root_hash : v.genesis_event_root_hash,
            state_checkpoint_hash : v.genesis_state_checkpoint_hash,
            gas_used : v.genesis_gas_used,
            vm_status : v.genesis_vm_status,
            accumulator_root_hash : v.genesis_accumulator_root_hash,
            timestamp : v.genesis_timestamp,
            success : v.genesis_success,
            payload : v.genesis_payload,
            changes : v.genesis_changes,
            events : v.genesis_events
        ).convertToJson().toJson()

    of BlockMetaTransaction:

        s = (
            `type` : $v.`type`, 
            hash : v.hash,
            version : v.block_version,
            state_change_hash : v.block_state_change_hash,
            event_root_hash : v.block_event_root_hash,
            state_checkpoint_hash : v.block_state_checkpoint_hash,
            gas_used : v.block_gas_used,
            vm_status : v.block_vm_status,
            accumulator_root_hash : v.block_accumulator_root_hash,
            timestamp : v.block_timestamp,
            success : v.block_success,
            id : v.id,
            epoch : v.epoch,
            round : v.round,
            proposer : v.proposer,
            previous_block_votes_bitvec : v.previous_block_votes_bitvec,
            failed_proposer_indices : v.failed_proposer_indices,
            changes : v.block_changes,
            events : v.block_events
        ).convertToJson().toJson()

    of StateCheckPointTransaction:

        s = (
            `type` : $v.`type`, 
            hash : v.hash,
            version : v.state_version,
            state_change_hash : v.state_state_change_hash,
            event_root_hash : v.state_event_root_hash,
            state_checkpoint_hash : v.state_state_checkpoint_hash,
            gas_used : v.state_gas_used,
            vm_status : v.state_vm_status,
            accumulator_root_hash : v.state_accumulator_root_hash,
            timestamp : v.state_timestamp,
            success : v.state_success,
            changes : v.state_changes
        ).convertToJson().toJson()

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

proc `$`*(data : Payload) : string = data.toJson()

proc `$`*(data : Change) : string = data.toJson()

proc `$`*(data : Transaction) : string = data.toJson()

proc `$`*(data : RawTransaction) : string = data.toJson()

proc `$`*(data : SignTransaction) : string = data.toJson()

proc `$`*(data : MultiAgentRawTransaction) : string = data.toJson()

proc `$`*(data : SubmittedTransaction) : string = data.toJson()

converter toSignTransaction*[T : RawTransaction | MultiAgentRawTransaction](txn : T) : SignTransaction =

    result = SignTransaction(
        chain_id : txn.chain_id,
        sender : txn.sender, 
        sequence_number : txn.sequence_number, 
        max_gas_amount : txn.max_gas_amount, 
        gas_unit_price : txn.gas_unit_price, 
        expiration_timestamp_secs : txn.expiration_timestamp_secs,
        payload : txn.payload
    )

converter toMultiAgentRawTransaction*[T : RawTransaction | SignTransaction](txn : T) : MultiAgentRawTransaction =

    result = MultiAgentRawTransaction(
        chain_id : txn.chain_id,
        sender : txn.sender, 
        sequence_number : txn.sequence_number, 
        max_gas_amount : txn.max_gas_amount, 
        gas_unit_price : txn.gas_unit_price, 
        expiration_timestamp_secs : txn.expiration_timestamp_secs,
        payload : txn.payload
    )

#[template toTuple*(txn : Transaction, code : untyped) =
    ## TODO :: manually define tuple types for each transactions
    
    let txnHash = txn.hash
    case txn.`type`

    of PendingTransaction:

        let transactionTuple {.inject.} = (
            `type` : PendingTransaction,
            #hash : txnHash,
            sender : txn.pending_sender, 
            sequence_number : txn.pending_sequence_number, 
            max_gax_amount : txn.pending_max_gas_amount, 
            gas_unit_price : txn.pending_gas_unit_price,
            expiration_timestamp_secs : txn.pending_expiration_timestamp_secs,
            payload : txn.pending_payload,
            signature : txn.pending_signature
        )
        code

    of UserTransaction:

        let transactionTuple {.inject.} = (
            `type` : UserTransaction,
            hash : txnHash,
            sender : txn.user_sender,
            sequence_number : txn.user_sequence_number, 
            max_gax_amount : txn.user_max_gas_amount, 
            gas_unit_price : txn.user_gas_unit_price,
            expiration_timestamp_secs : txn.user_expiration_timestamp_secs,
            version : txn.user_version,
            state_change_hash : txn.user_state_change_hash, 
            event_root_hash : txn.user_event_root_hash, 
            state_checkpoint_hash : txn.user_state_checkpoint_hash, 
            gas_used : txn.user_gas_used,
            vm_status : txn.user_vm_status, 
            accumulator_root_hash : txn.user_accumulator_root_hash,
            timestamp : txn.user_timestamp,
            success : txn.user_success,
            payload : txn.user_payload,
            signature : txn.user_signature,
            changes : txn.user_changes,
            events : txn.user_events
        )
        code

    of GenesisTransaction:

        let transactionTuple {.inject.} = (
            `type` : GenesisTransaction,
            hash : txnHash,
            version : txn.genesis_version, 
            state_change_hash : txn.genesis_state_change_hash,
            event_root_hash : txn.genesis_event_root_hash, 
            state_checkpoint_hash : txn.genesis_state_checkpoint_hash, 
            gas_used : txn.genesis_gas_used, 
            vm_status : txn.genesis_vm_status, 
            accumulator_root_hash : txn.genesis_accumulator_root_hash, 
            timestamp : txn.genesis_timestamp,
            success : txn.genesis_success,
            payload : txn.genesis_payload,
            changes : txn.genesis_changes,
            events : txn.genesis_events,
        )
        code

    of BlockMetaTransaction:

        let transactionTuple {.inject.} = (
            `type` : BlockMetaTransaction,
            hash : txnHash,
            version : txn.block_version, 
            state_change_hash : txn.block_state_change_hash, 
            event_root_hash : txn.block_event_root_hash, 
            state_checkpoint_hash : txn.block_state_checkpoint_hash, 
            gas_used : txn.block_gas_used,
            vm_status : txn.block_vm_status, 
            accumulator_root_hash : txn.block_accumulator_root_hash, 
            timestamp : txn.block_timestamp,
            success : txn.block_success,
            id : txn.id, 
            epoch : txn.epoch, 
            round : txn.round, 
            proposer : txn.proposer,
            previous_block_votes_bitvec : txn.previous_block_votes_bitvec,
            failed_proposer_indices : txn.failed_proposer_indices,
            changes : txn.block_changes,
            events : txn.block_events
        )
        code

    of StateCheckPointTransaction:
        
        let transactionTuple {.inject.} = (
            `type` : StateCheckPointTransaction,
            hash : txnHash,
            version : txn.state_version, 
            state_change_hash : txn.state_state_change_hash, 
            event_root_hash : txn.state_event_root_hash, 
            state_checkpoint_hash : txn.state_state_checkpoint_hash, 
            gas_used : txn.state_gas_used,
            vm_status : txn.state_vm_status, 
            accumulator_root_hash : txn.state_accumulator_root_hash, 
            timestamp : txn.state_timestamp,
            success : txn.state_success,
            changes : txn.state_changes
        )
        code]#

#[converter fromAbi*(data : string) : MoveModuleByteCode =

    discard

converter fromAbi*(data : string) : MoveScriptByteCode =

    discard]#

