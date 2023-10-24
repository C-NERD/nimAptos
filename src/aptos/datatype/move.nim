import std / [json]
from std / strutils import parseHexStr
import pkg / [jsony]

type

    BcsStatus* {.pure.} = enum
        ## special status for bcs type
        None
        HexString

    BcsJsonType* = object
        ## nim representation of bcs types
        value : JsonNode
        status : BcsStatus

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

proc isHex(data : string) : bool =

    try:

        discard parseHexStr(data)
        return true

    except ValueError:

        return false

proc newBcsType*(value : JsonNode) : BcsJsonType =
    
    var status : BcsStatus = None
    case value.kind

    of JString:

        if isHex(value.str):

            status = BcsStatus.HexString

    else:

        discard

    BcsJsonType(value : value, status : status)

proc bcsVal*(data : BcsJsonType) : JsonNode = data.value

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

