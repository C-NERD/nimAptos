## std imports
import std / [uri, httpcore, logging]
from std / json import `$`, `[]`, `[]=`, JsonNode, JsonParsingError, items, newJString, getInt
from std / strformat import fmt
from std / strutils import split, strip, parseInt, contains, isEmptyOrWhitespace

## nimble imports
import pkg / [jsony]

## project imports
import ../datatype
#import ../datatypeutils

when not defined(js):

    import std / [httpclient, asyncdispatch, locks]

else:

    import std / [jsfetch, asyncjs, jsheaders]

type

    InvalidApiResponse* = object of ValueError

    ApiError* = object of HttpRequestError

    AptosClient = object

        nodeInfo : LedgerInfo
        baseUrl : Uri
        when not defined(js):

            client {.guard : clientLock.} : AsyncHttpClient
            clientLock : Lock

    RefAptosClient* = ref AptosClient

## client specific procs
proc getNodeInfo*(client : RefAptosClient) : LedgerInfo = client.nodeInfo

when defined(debug):

    var logger = newConsoleLogger(fmtStr = "$time :: $levelname -> ", useStderr = true)

template callAptosNode(aptosClient : RefAptosClient, path : string, `method` : HttpMethod, params : seq[(string, string)], 
    payload : tuple | object | ref object | seq, callback : untyped) =

    var endpoint = aptosClient.baseUrl / path
    endpoint.query = encodeQuery(params)

    when defined(debug):
        
        let logHeader = "[" & $`method` & "] :: " & $endpoint
        logger.log(lvlInfo, logHeader)
        logger.log(lvlDebug, logHeader & "\n" & $payload)

    when not defined(js):

        var 
            response {.inject.} : AsyncResponse = nil
            headers = newHttpHeaders(@[(key : "Accept", val : "application/json")])
        if `method` == HttpPost:

            headers.add "Content-Type", "application/json"

        withLock aptosClient.clientLock:

            response = await aptosClient.client.request(endpoint, `method`, toJson(payload), headers)

        let 
            respBody {.inject.} = await response.body()
            respCode = response.status.split()[0].parseInt()

        if respCode notin 200..299:

            raise newException(ApiError, respBody)

    else:

        var 
            respBody {.inject.} : string
            req = newRequest(($endpoint).cstring)
            headers = newHeaders()
        
        headers["Accept"] = "application/json"
        if `method` == HttpPost:

            headers["Content-Type"] = "application/json"

        req.headers = headers
        fetch(req, newfetchOptions(`method`, toJson(payload), fmCors, fcInclude, fchDefault, frpNoReferrer, true))
            .then(proc(resp : Response) =

                respBody = $resp.body
                if not resp.ok:

                    raise newException(ApiError, respBody)
            , proc(err : Error) =

                raise newException(ApiError, err.name & " :: " & err.message)
            )
    
    when defined(debug):

        logger.log(lvlDebug, logHeader & "\n" & respBody)

    callback

## Account Api Calls
proc getAccount*(client : RefAptosClient, address : string, ledger_version : int64 = -1) : 
    Future[AccountResource] {.async, gcsafe.} =
    ## proc to get account information
    
    var params : seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    callAptosNode client, fmt"accounts/{address}", HttpGet, params, ():

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:
            
            raise newException(InvalidApiResponse, respBody)

proc getAccountResource*(client : RefAptosClient, address : string, resource_type : ResourceType, 
    ledger_version : int64 = -1) : Future[MoveResource] {.async, gcsafe.} =

    var params : seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    callAptosNode client, fmt"accounts/{address}/resource/{encodeUrl($resource_type)}", HttpGet, params, ():

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:
            
            raise newException(InvalidApiResponse, respBody)

proc getAccountResources*(client : RefAptosClient, address : string, ledger_version : int64 = -1, 
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

    callAptosNode client, fmt"/accounts/{address}/resources", HttpGet, params, ():

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:
            
            raise newException(InvalidApiResponse, respBody)

proc getAccountModule*(client : RefAptosClient, address, module_name : string, ledger_version : int64 = -1) : 
    Future[MoveModuleByteCode] {.gcsafe, async.} =

    var params : seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    callAptosNode client, fmt"accounts/{address}/module/{module_name}", HttpGet, params, ():

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:
            
            raise newException(InvalidApiResponse, respBody)

proc getAccountModules*(client : RefAptosClient, address : string, ledger_version : int64 = -1, limit : int = -1, 
    start : string = "") : Future[seq[MoveModuleByteCode]] {.gcsafe, async.} =

    var params : seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    if limit >= 0:

        params.add ("limit", $limit)

    if not start.isEmptyOrWhitespace():

        params.add ("start", start)

    callAptosNode client, fmt"accounts/{address}/modules", HttpGet, params, ():

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:
            
            raise newException(InvalidApiResponse, respBody)

## Block Api calls
proc getBlockByHeight*(client : RefAptosClient, height : int, with_transactions : bool = false) : 
    Future[Block] {.async, gcsafe.} =

    var params : seq[(string, string)] = @[("with_transactions", $with_transactions)]
    callAptosNode client, fmt"blocks/by_height/{height}", HttpGet, params, ():

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

proc getBlockByVersion*(client : RefAptosClient, version : int, with_transactions : bool = false) : 
    Future[Block] {.async, gcsafe.} =

    var params : seq[(string, string)] = @[("with_transactions", $with_transactions)]
    callAptosNode client, fmt"blocks/by_version/{version}", HttpGet, params, ():

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

## Events Api calls
proc getEventsByCreationNum*(client : RefAptosClient, address : string, creation_number : uint64, limit : int = -1, 
    start : int64 = -1) : Future[seq[Event]] {.async, gcsafe.} = 

    var params : seq[(string, string)]
    if limit >= 0:

        params.add ("limit", $limit)

    if start >= 0:

        params.add ("start", $start)

    callAptosNode client, fmt"accounts/{address}/events/{creation_number}", HttpGet, params, ():

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

proc getEventsByHandle*(client : RefAptosClient, address, handle, fieldName : string, limit : int = -1, 
    start : int64 = -1) : Future[seq[Event]] {.async, gcsafe.} = 

    var params : seq[(string, string)]
    if limit >= 0:

        params.add ("limit", $limit)

    if start >= 0:

        params.add ("start", $start)
        
    callAptosNode client, fmt"accounts/{address}/events/{handle}/{fieldName}", HttpGet, params, ():

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

## General Api calls
proc isNodeHealthy*(client : RefAptosClient, duration_secs : int = -1) : Future[bool] {.async, gcsafe.} =

    var params : seq[(string, string)]
    if duration_secs >= 0:

        params.add ("duration_secs", $duration_secs)

    try:

        callAptosNode client, "-/healthy", HttpGet, params, ():

            discard

        result = true

    except ApiError:

        discard

proc getLedgerInfo*(client : RefAptosClient) : Future[LedgerInfo] {.async, gcsafe.} =

    callAptosNode client, "", HttpGet, @[], ():

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:
            
            raise newException(InvalidApiResponse, respBody)

## Table Api calls
proc getTableItem*(client : RefAptosClient, handle : string, payload : tuple[key_type, value_type, key : string], 
    ledger_version : int64 = -1) : Future[JsonNode] {.async, gcsafe.} =

    var params : seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)
    
    callAptosNode client, fmt"tables/{handle}/item", HttpPost, params, payload:

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

proc getRawTableItem*(client : RefAptosClient, handle : string, payload : tuple[key : string], 
    ledger_version : int64 = -1) : Future[JsonNode] {.async, gcsafe.} =

    var params : seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)
    
    callAptosNode client, fmt"tables/{handle}/raw_item", HttpPost, params, payload:

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

## Transaction Api calls
proc getTransactions*(client : RefAptosClient, limit : int = -1, start : int64 = -1) : 
    Future[seq[Transaction]] {.async, gcsafe.} =

    var params : seq[(string, string)]
    if limit >= 0:

        params.add ("limit", $limit)

    if start >= 0:

        params.add ("start", $start)
    
    callAptosNode client, "transactions", HttpGet, params, ():

        try:
            
            result = respBody.fromJson(typeof(result))
        
        except JsonError, JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

method submitTransaction*(client : RefAptosClient, transaction : SignTransaction) : 
    Future[SubmittedTransaction] {.async, gcsafe.} =
    
    callAptosNode client, "transactions", HttpPost, @[], transaction:

        try:
            
            result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

proc getTransactionByHash*(client : RefAptosClient, hash : string) : Future[Transaction] {.async, gcsafe.} =

    callAptosNode client, fmt"transactions/by_hash/{hash}", HttpGet, @[], ():

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

proc getTransactionByVersion*(client : RefAptosClient, version : uint64) : Future[Transaction] {.async, gcsafe.} =

    callAptosNode client, fmt"transactions/by_version/{version}", HttpGet, @[], ():

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

proc getAccountTransactions*(client : RefAptosClient, address : string, limit : int = -1, start : int64 = -1) : 
    Future[seq[Transaction]] {.async, gcsafe.} =

    var params : seq[(string, string)]
    if limit >= 0:

        params.add ("limit", $limit)

    if start >= 0:

        params.add ("start", $start)

    callAptosNode client, fmt"accounts/{address}/transactions", HttpGet, params, ():

        try:
        
            result = respBody.fromJson(typeof(result))
        
        except JsonError, JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

method submitBatchTransactions*(client : RefAptosClient, transactions : seq[SignTransaction]) : Future[tuple[
    transaction_failures : seq[tuple[error : Error, transaction_index : int]]
    ]] {.async, gcsafe.} =

    callAptosNode client, "transactions/batch", HttpPost, @[], transactions:

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

proc simulateTransaction*(client : RefAptosClient, transaction : RawTransaction, estimate_gas_unit_price, 
    estimate_max_gas_amount, estimate_prioritized_gas_unit_price : bool = false) : 
    Future[seq[Transaction]] {.async, gcsafe.} =

    callAptosNode client, "transactions/simulate", HttpPost, @[
        ("estimate_gas_unit_price", $estimate_gas_unit_price),
        ("estimate_max_gas_amount", $estimate_max_gas_amount),
        ("estimate_prioritized_gas_unit_price", $estimate_prioritized_gas_unit_price)
    ], transaction:

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

method encodeSubmission*(client : RefAptosClient, transaction : RawTransaction) : Future[string] {.async, gcsafe.} =
    
    callAptosNode client, "transactions/encode_submission", HttpPost, @[], transaction:

        result = respBody
        result = result.strip(chars = {'"'})

method encodeSubmission*(client : RefAptosClient, transaction : MultiAgentRawTransaction) : 
    Future[string] {.async, gcsafe.} =

    ## for multi agent signature
    callAptosNode client, "transactions/encode_submission", HttpPost, @[], transaction:

        result = respBody
        result = result.strip(chars = {'"'})

proc estimateGasPrice*(client : RefAptosClient) : 
    Future[tuple[deprioritized_gas_estimate, gas_estimate, prioritized_gas_estimate : int]] {.async, gcsafe.} =

    callAptosNode client, "estimate_gas_price", HttpGet, @[], ():

        try:

            result = respBody.fromJson(typeof(result))
        
        except JsonError:

            raise newException(InvalidApiResponse, respBody)

## View Api calls
proc executeModuleView*(client : RefAptosClient, payload : ViewRequest, ledger_version : int64 = -1) : Future[string] {.async, gcsafe.} =
    ## returns json as string

    var params : seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)
        
    callAptosNode client, "view", HttpPost, params, payload:

        result = respBody

## Faucet Api call
proc faucetFund*(client : RefAptosClient, address : string, amount : int) : Future[seq[string]] {.async, gcsafe.} =
    ## This function is only meant to be called when using the devnet
    ## returns sequence of transaction hash
    
    callAptosNode client, "mint", HttpPost, @[("amount", $amount), ("address", address)], ():

        try:

            return respBody.fromJson(typeof(result))

        except JsonError:

            raise newException(InvalidApiResponse, respBody)

## Api utils procs
proc newAptosClient*(nodeUrl : string, faucet : bool = false) : RefAptosClient =

    new(result)
    when not defined(js):
        
        initLock(result.clientLock)
        withLock result.clientLock:

            result.client = newAsyncHttpClient()

    result.baseUrl = parseUri(nodeUrl)
    if not faucet:

        result.nodeInfo = waitFor result.getLedgerInfo()

when not defined(js):
    
    proc close*(client : RefAptosClient) =

        withLock client.clientLock:

            client.client.close()

        deinitLock(client.clientLock)

