import std / [json]
import pkg / [jsony]
from std / strutils import parseEnum
from std / jsonutils import toJson

import ../datatype/[payload, signature, change, event]

type

    InvalidTransaction* = object of ValueError

    Error* = object

        message, error_code : string
        vm_error_code : int 
     
    ViewRequest* = object

        function* : string
        type_arguments* : seq[string]
        arguments* : seq[JsonNode]  

    LedgerInfo* = object

        chain_id* : int8
        epoch*, ledger_version*, oldest_ledger_version*, ledger_timestamp*, node_role*, oldest_block_height*, block_height*, git_hash* : string

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

    Block* = object

        block_height*, block_hash*, block_timestamp*, first_version*, last_version* : string
        transactions* : seq[Transaction]

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

proc toJsonStr(data : tuple) : string = jsony.toJson(jsonutils.toJson(data))

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
        ).toJsonStr()

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
        ).toJsonStr()

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
        ).toJsonStr()

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
        ).toJsonStr()

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
        ).toJsonStr()

proc `$`*(data : Transaction) : string = jsony.toJson(data)

