#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementation for aptos node client procs

## {.experimental : "codeReordering".}
## std imports
import std / [uri, json, jsonutils, httpcore, strutils]
from std / strformat import fmt

## project imports
import nodetypes, utils
import ../aptostypes/[resourcetypes, transaction]
import ../aptostypes/payload/payload

export ApiError, InvalidApiResponse, AptosClient, getNodeInfo, close

## Account Api Calls
proc getAccount*(client: AptosClient, address: string,
        ledger_version: int64 = -1):
    Future[AccountData] {.async, gcsafe.} =
    ## proc to get account information

    var params: seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    callNode client, fmt"accounts/{address}", HttpGet, params, ():

        try:

            {.cast(gcsafe).}:

                result = jsonTo(parseJson(respBody), AccountData)

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

proc getAccountResource*(client: AptosClient, address, resource_type: string,
    ledger_version: int64 = -1): Future[MoveResource] {.async, gcsafe.} =

    var params: seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    callNode client, fmt"accounts/{address}/resource/{encodeUrl(resource_type)}",
            HttpGet, params, ():

        try:

            {.cast(gcsafe).}:

                result = jsonTo(parseJson(respBody), MoveResource)

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

proc getAccountResources*(client: AptosClient, address: string,
        ledger_version: int64 = -1,
    limit: int = -1, start: string = ""): Future[seq[MoveResource]] {.async, gcsafe.} =

    var params: seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    if not start.isEmptyOrWhitespace():

        params.add ("start", start)

    if limit >= 0:

        params.add ("limit", $limit)

    callNode client, fmt"/accounts/{address}/resources", HttpGet, params, ():

        try:

            {.cast(gcsafe).}:

                result = jsonTo(parseJson(respBody), seq[MoveResource])

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

proc getAccountModule*(client: AptosClient, address, module_name: string,
        ledger_version: int64 = -1):
    Future[MoveModule] {.gcsafe, async.} =

    var params: seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    callNode client, fmt"accounts/{address}/module/{module_name}", HttpGet,
            params, ():

        try:

            {.cast(gcsafe).}:

                result = jsonTo(parseJson(respBody), MoveModule)

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

proc getAccountModules*(client: AptosClient, address: string,
        ledger_version: int64 = -1, limit: int = -1,
    start: string = ""): Future[seq[MoveModule]] {.gcsafe, async.} =

    var params: seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    if limit >= 0:

        params.add ("limit", $limit)

    if not start.isEmptyOrWhitespace():

        params.add ("start", start)

    callNode client, fmt"accounts/{address}/modules", HttpGet, params, ():

        try:

            {.cast(gcsafe).}:

                result = jsonTo(parseJson(respBody), seq[MoveModule])

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

## Block Api calls
proc getBlockByHeight*(client: AptosClient, height: int,
        with_transactions: bool = false):
    Future[Block] {.async, gcsafe.} =

    var params: seq[(string, string)] = @[("with_transactions",
            $with_transactions)]
    callNode client, fmt"blocks/by_height/{height}", HttpGet, params, ():

        try:

            {.cast(gcsafe).}:

                result = jsonTo(parseJson(respBody), Block)

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

proc getBlockByVersion*(client: AptosClient, version: int,
        with_transactions: bool = false):
    Future[Block] {.async, gcsafe.} =

    var params: seq[(string, string)] = @[("with_transactions",
            $with_transactions)]
    callNode client, fmt"blocks/by_version/{version}", HttpGet, params, ():

        try:

            {.cast(gcsafe).}:

                result = jsonTo(parseJson(respBody), Block)

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

## Events Api calls
proc getEventsByCreationNum*(client: AptosClient, address: string,
        creation_number: uint64, limit: int = -1,
    start: int64 = -1): Future[JsonNode] {.async, gcsafe.} =

    var params: seq[(string, string)]
    if limit >= 0:

        params.add ("limit", $limit)

    if start >= 0:

        params.add ("start", $start)

    callNode client, fmt"accounts/{address}/events/{creation_number}", HttpGet,
            params, ():

        try:

            result = parseJson respBody

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

proc getEventsByHandle*(client: AptosClient, address, handle, fieldName: string,
        limit: int = -1,
    start: int64 = -1): Future[JsonNode] {.async, gcsafe.} =

    var params: seq[(string, string)]
    if limit >= 0:

        params.add ("limit", $limit)

    if start >= 0:

        params.add ("start", $start)

    callNode client, fmt"accounts/{address}/events/{handle}/{fieldName}",
            HttpGet, params, ():

        try:

            result = parseJson respBody

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

## General Api calls
proc isNodeHealthy*(client: AptosClient, duration_secs: int = -1): Future[
        bool] {.async, gcsafe.} =

    var params: seq[(string, string)]
    if duration_secs >= 0:

        params.add ("duration_secs", $duration_secs)

    try:

        callNode client, "-/healthy", HttpGet, params, ():

            discard

        result = true

    except ApiError:

        result = false

proc getLedgerInfo*(client: AptosClient): Future[LedgerInfo] {.async, gcsafe.} =

    callNode client, "", HttpGet, @[], ():

        try:

            {.cast(gcsafe).}:

                result = jsonTo(parseJson(respBody), LedgerInfo)

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

## Table Api calls
proc getTableItem*(client: AptosClient, handle: string, payload: tuple[key_type,
        value_type, key: string],
    ledger_version: int64 = -1): Future[JsonNode] {.async, gcsafe.} =

    var params: seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    callNode client, fmt"tables/{handle}/item", HttpPost, params, payload:

        try:

            result = parseJson respBody

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

proc getRawTableItem*(client: AptosClient, handle: string, payload: tuple[
        key: string],
    ledger_version: int64 = -1): Future[JsonNode] {.async, gcsafe.} =

    var params: seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    callNode client, fmt"tables/{handle}/raw_item", HttpPost, params, payload:

        try:

            result = parseJson respBody

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

## Transaction Api calls
proc getTransactions*(client: AptosClient, limit: int = -1, start: int64 = -1):
    Future[JsonNode] {.async, gcsafe.} =

    var params: seq[(string, string)]
    if limit >= 0:

        params.add ("limit", $limit)

    if start >= 0:

        params.add ("start", $start)

    callNode client, "transactions", HttpGet, params, ():

        try:

            result = parseJson respBody

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

proc submitTransaction*[T: TransactionPayload](client: AptosClient,
        transaction: SignedTransaction[T]): Future[SubmittedTransaction[
        T]] {.async, gcsafe.} =

    callNode client, "transactions", HttpPost, @[], transaction:

        try:

            {.cast(gcsafe).}:

                fromJsonHook(result, parseJson(respBody))

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

proc getTransactionByHash*(client: AptosClient, hash: string): Future[
        JsonNode] {.async, gcsafe.} =

    callNode client, fmt"transactions/by_hash/{hash}", HttpGet, @[], ():

        try:

            result = parseJson respBody

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

proc getTransactionByVersion*(client: AptosClient, version: uint64): Future[
        JsonNode] {.async, gcsafe.} =

    callNode client, fmt"transactions/by_version/{version}", HttpGet, @[], ():

        try:

            result = parseJson respBody

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

proc getAccountTransactions*(client: AptosClient, address: string,
        limit: int = -1, start: int64 = -1):
    Future[JsonNode] {.async, gcsafe.} =
    var params: seq[(string, string)]
    if limit >= 0:

        params.add ("limit", $limit)

    if start >= 0:

        params.add ("start", $start)

    callNode client, fmt"accounts/{address}/transactions", HttpGet, params, ():

        try:

            result = parseJson respBody

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

proc submitBatchTransactions*[T: tuple](client: AptosClient,
        transactions: T): Future[JsonNode] {.async, gcsafe.} =
    ## param transaction : This should be a tuple of SignednTransactions

    callNode client, "transactions/batch", HttpPost, @[], transactions:

        try:

            result = parseJson respBody

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

proc simulateTransaction*(client: AptosClient, transaction: SignedTransaction,
        estimate_gas_unit_price = false; estimate_max_gas_amount = false;
        estimate_prioritized_gas_unit_price: bool = false):
    Future[JsonNode] {.gcsafe, async.} =

    callNode client, "transactions/simulate", HttpPost, @[
        ("estimate_gas_unit_price", $estimate_gas_unit_price),
        ("estimate_max_gas_amount", $estimate_max_gas_amount),
        ("estimate_prioritized_gas_unit_price",
                $estimate_prioritized_gas_unit_price)
    ], transaction:

        try:

            result = parseJson respBody

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

proc encodeSubmission*(client: AptosClient,
        transaction: RawTransaction): Future[string] {.async, gcsafe.} =

    callNode client, "transactions/encode_submission", HttpPost, @[], transaction:

        result = respBody
        result = result.strip(chars = {'"'})

proc encodeSubmission*(client: AptosClient,
        transaction: MultiAgentRawTransaction):
    Future[string] {.async, gcsafe.} =

    ## for multi agent signature
    callNode client, "transactions/encode_submission", HttpPost, @[], transaction:

        result = respBody
        result = result.strip(chars = {'"'})

proc estimateGasPrice*(client: AptosClient):
    Future[tuple[deprioritized_gas_estimate, gas_estimate,
            prioritized_gas_estimate: int]] {.async, gcsafe.} =

    callNode client, "estimate_gas_price", HttpGet, @[], ():

        try:

            {.cast(gcsafe).}:

                result = jsonTo(parseJson(respBody), tuple[
                        deprioritized_gas_estimate, gas_estimate,
                        prioritized_gas_estimate: int])

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

## View Api calls
proc executeModuleView*[T: tuple](client: AptosClient, payload: ViewRequest[T],
        ledger_version: int64 = -1): Future[string] {.async, gcsafe.} =
    ## returns json as string

    var params: seq[(string, string)]
    if ledger_version >= 0:

        params.add ("ledger_version", $ledger_version)

    callNode client, "view", HttpPost, params, toJsonHook(payload):

        result = respBody

proc newAptosClient*(nodeUrl: string): AptosClient =

    result = utils.newPrimitiveAptosClient(nodeUrl)
    result.setNodeInfo(waitFor result.getLedgerInfo())

