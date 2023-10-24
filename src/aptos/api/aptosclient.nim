## {.experimental : "codeReordering".}
## std imports
import std / [uri, httpcore, strutils]
import std / json except JsonError
from std / strformat import fmt

## nimble imports
import pkg / [jsony]

## project imports
import nodetypes, utils
import ../datatype/[move, transaction, event]

export ApiError, InvalidApiResponse, AptosClient, getNodeInfo, close

#[when defined(debug):
    
    import std / logging

    var logger = newConsoleLogger(fmtStr = "$time :: $levelname -> ", useStderr = true)]#

## Account Api Calls
proc getAccount*(client : AptosClient, address : string, ledger_version : int64 = -1) : 
    Future[AccountResource] {.async, gcsafe.} =
    ## proc to get account information
    
    var params : seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    callNode client, fmt"accounts/{address}", HttpGet, params, ():

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:
            
            raise newException(InvalidApiResponse, respBody)

proc getAccountResource*(client : AptosClient, address : string, resource_type : ResourceType, 
    ledger_version : int64 = -1) : Future[MoveResource] {.async, gcsafe.} =

    var params : seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    callNode client, fmt"accounts/{address}/resource/{encodeUrl($resource_type)}", HttpGet, params, ():

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:
            
            raise newException(InvalidApiResponse, respBody)

proc getAccountResources*(client : AptosClient, address : string, ledger_version : int64 = -1, 
    limit : int = -1, start : string = "") : Future[seq[
    MoveResource
    ]] {.async, gcsafe.} =

    var params : seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    if not start.isEmptyOrWhitespace():

        params.add ("start", start)

    if limit >= 0:

        params.add ("limit", $limit)

    callNode client, fmt"/accounts/{address}/resources", HttpGet, params, ():

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:
            
            raise newException(InvalidApiResponse, respBody)

proc getAccountModule*(client : AptosClient, address, module_name : string, ledger_version : int64 = -1) : 
    Future[MoveModuleByteCode] {.gcsafe, async.} =

    var params : seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    callNode client, fmt"accounts/{address}/module/{module_name}", HttpGet, params, ():

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:
            
            raise newException(InvalidApiResponse, respBody)

proc getAccountModules*(client : AptosClient, address : string, ledger_version : int64 = -1, limit : int = -1, 
    start : string = "") : Future[seq[MoveModuleByteCode]] {.gcsafe, async.} =

    var params : seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    if limit >= 0:

        params.add ("limit", $limit)

    if not start.isEmptyOrWhitespace():

        params.add ("start", start)

    callNode client, fmt"accounts/{address}/modules", HttpGet, params, ():

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:
            
            raise newException(InvalidApiResponse, respBody)

## Block Api calls
proc getBlockByHeight*(client : AptosClient, height : int, with_transactions : bool = false) : 
    Future[Block] {.async, gcsafe.} =

    var params : seq[(string, string)] = @[("with_transactions", $with_transactions)]
    callNode client, fmt"blocks/by_height/{height}", HttpGet, params, ():

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

proc getBlockByVersion*(client : AptosClient, version : int, with_transactions : bool = false) : 
    Future[Block] {.async, gcsafe.} =

    var params : seq[(string, string)] = @[("with_transactions", $with_transactions)]
    callNode client, fmt"blocks/by_version/{version}", HttpGet, params, ():

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

## Events Api calls
proc getEventsByCreationNum*(client : AptosClient, address : string, creation_number : uint64, limit : int = -1, 
    start : int64 = -1) : Future[seq[Event]] {.async, gcsafe.} = 

    var params : seq[(string, string)]
    if limit >= 0:

        params.add ("limit", $limit)

    if start >= 0:

        params.add ("start", $start)

    callNode client, fmt"accounts/{address}/events/{creation_number}", HttpGet, params, ():

        try:
            
            {.cast(gcsafe).}:
                
                result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

proc getEventsByHandle*(client : AptosClient, address, handle, fieldName : string, limit : int = -1, 
    start : int64 = -1) : Future[seq[Event]] {.async, gcsafe.} = 

    var params : seq[(string, string)]
    if limit >= 0:

        params.add ("limit", $limit)

    if start >= 0:

        params.add ("start", $start)
        
    callNode client, fmt"accounts/{address}/events/{handle}/{fieldName}", HttpGet, params, ():

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

## General Api calls
proc isNodeHealthy*(client : AptosClient, duration_secs : int = -1) : Future[bool] {.async, gcsafe.} =

    var params : seq[(string, string)]
    if duration_secs >= 0:

        params.add ("duration_secs", $duration_secs)

    try:

        callNode client, "-/healthy", HttpGet, params, ():

            discard

        result = true

    except ApiError:

        discard

proc getLedgerInfo*(client : AptosClient) : Future[LedgerInfo] {.async, gcsafe.} =

    callNode client, "", HttpGet, @[], ():

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:
            
            raise newException(InvalidApiResponse, respBody)

## Table Api calls
proc getTableItem*(client : AptosClient, handle : string, payload : tuple[key_type, value_type, key : string], 
    ledger_version : int64 = -1) : Future[JsonNode] {.async, gcsafe.} =

    var params : seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)
    
    callNode client, fmt"tables/{handle}/item", HttpPost, params, payload:

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

proc getRawTableItem*(client : AptosClient, handle : string, payload : tuple[key : string], 
    ledger_version : int64 = -1) : Future[JsonNode] {.async, gcsafe.} =

    var params : seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)
    
    callNode client, fmt"tables/{handle}/raw_item", HttpPost, params, payload:

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

## Transaction Api calls
proc getTransactions*(client : AptosClient, limit : int = -1, start : int64 = -1) : 
    Future[seq[Transaction]] {.async, gcsafe.} =

    var params : seq[(string, string)]
    if limit >= 0:

        params.add ("limit", $limit)

    if start >= 0:

        params.add ("start", $start)
    
    callNode client, "transactions", HttpGet, params, ():

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError, JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

method submitTransaction*(client : AptosClient, transaction : SignTransaction) : 
    Future[SubmittedTransaction] {.async, gcsafe, base.} =
    
    callNode client, "transactions", HttpPost, @[], transaction:

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

proc getTransactionByHash*(client : AptosClient, hash : string) : Future[Transaction] {.async, gcsafe.} =

    callNode client, fmt"transactions/by_hash/{hash}", HttpGet, @[], ():

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

proc getTransactionByVersion*(client : AptosClient, version : uint64) : Future[Transaction] {.async, gcsafe.} =

    callNode client, fmt"transactions/by_version/{version}", HttpGet, @[], ():

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

proc getAccountTransactions*(client : AptosClient, address : string, limit : int = -1, start : int64 = -1) : 
    Future[seq[Transaction]] {.async, gcsafe.} =

    var params : seq[(string, string)]
    if limit >= 0:

        params.add ("limit", $limit)

    if start >= 0:

        params.add ("start", $start)

    callNode client, fmt"accounts/{address}/transactions", HttpGet, params, ():

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError, JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

method submitBatchTransactions*(client : AptosClient, transactions : seq[SignTransaction]) : Future[tuple[
    transaction_failures : seq[tuple[error : Error, transaction_index : int]]
    ]] {.async, gcsafe, base.} =

    callNode client, "transactions/batch", HttpPost, @[], transactions:

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

proc simulateTransaction*(client : AptosClient, transaction : RawTransaction, estimate_gas_unit_price, 
    estimate_max_gas_amount, estimate_prioritized_gas_unit_price : bool = false) : 
    Future[seq[Transaction]] {.async, gcsafe.} =

    callNode client, "transactions/simulate", HttpPost, @[
        ("estimate_gas_unit_price", $estimate_gas_unit_price),
        ("estimate_max_gas_amount", $estimate_max_gas_amount),
        ("estimate_prioritized_gas_unit_price", $estimate_prioritized_gas_unit_price)
    ], transaction:

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

method encodeSubmission*(client : AptosClient, transaction : RawTransaction) : Future[string] {.async, gcsafe, base.} =
    
    callNode client, "transactions/encode_submission", HttpPost, @[], transaction:

        result = respBody
        result = result.strip(chars = {'"'})

method encodeSubmission*(client : AptosClient, transaction : MultiAgentRawTransaction) : 
    Future[string] {.async, gcsafe, base.} =

    ## for multi agent signature
    callNode client, "transactions/encode_submission", HttpPost, @[], transaction:

        result = respBody
        result = result.strip(chars = {'"'})

proc estimateGasPrice*(client : AptosClient) : 
    Future[tuple[deprioritized_gas_estimate, gas_estimate, prioritized_gas_estimate : int]] {.async, gcsafe.} =

    callNode client, "estimate_gas_price", HttpGet, @[], ():

        try:
            
            {.cast(gcsafe).}:

                result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

## View Api calls
proc executeModuleView*(client : AptosClient, payload : ViewRequest, ledger_version : int64 = -1) : Future[string] {.async, gcsafe.} =
    ## returns json as string

    var params : seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)
        
    callNode client, "view", HttpPost, params, payload:

        result = respBody

proc newAptosClient*(nodeUrl : string) : AptosClient =
    
    result = utils.newAptosClient(nodeUrl)
    result.setNodeInfo(waitFor result.getLedgerInfo())

