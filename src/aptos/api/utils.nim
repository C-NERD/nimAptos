from std / uri import parseUri, Uri, `/`, encodeQuery
from nodetypes import LedgerInfo
from std / strutils import split, parseInt

import pkg / [jsony]

export split, parseInt, `/`, encodeQuery 

when defined(debug):

    import logging
    export logging        

when not defined(js):

    import std / [httpclient, asyncdispatch, locks]
    export httpclient, asyncdispatch, locks

else:

    import std / [jsfetch, asyncjs, jsheaders]
    export jsfetch, asyncjs, jsheaders

type

    InvalidApiResponse* = object of ValueError

    ApiError* = object of HttpRequestError

    BaseClient = ref object of RootObj
 
        baseUrl : Uri
        when not defined(js):

            client {.guard : clientLock.} : AsyncHttpClient
            clientLock : Lock

    AptosClient* = ref object of BaseClient

        nodeInfo : LedgerInfo

    FaucetClient* = ref object of BaseClient

template callNode*(client : BaseClient, path : string, `method` : HttpMethod, params : seq[(string, string)], 
    payload : tuple | object | ref object | seq, callback : untyped) =

    var endpoint = client.baseUrl / path
    endpoint.query = encodeQuery(params)
    when defined(debug):
        
        let logHeader = "[" & $`method` & "] :: " & $endpoint
        info(logHeader)
        {.cast(gcsafe).}:

            debug(logHeader & "\n" & $payload)

    when not defined(js):

        var 
            response {.inject.} : AsyncResponse = nil
            headers = newHttpHeaders(@[(key : "Accept", val : "application/json")]) 

        when defined(debug):
        
            info(logHeader & "\n" & $headers)
        
        var jPayload : string
        if `method` == HttpPost:

            headers.add "Content-Type", "application/json"
            withLock client.clientLock:
            
                {.cast(gcsafe).}:

                    jPayload = toJson(payload)
        
        withLock client.clientLock:

            response = await client.client.request(endpoint, `method`, jPayload, headers)

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
 
        when defined(debug):
        
            info(logHeader & "\n" & $headers)

        req.headers = headers
        {.cast(gcsafe).}:

            let jPayload = toJson(payload)

        fetch(req, newfetchOptions(`method`, jPayload, fmCors, fcInclude, fchDefault, frpNoReferrer, true))
            .then(proc(resp : Response) =

                respBody = $resp.body
                if not resp.ok:

                    raise newException(ApiError, respBody)
            , proc(err : Error) =

                raise newException(ApiError, err.name & " :: " & err.message)
            )
    
    when defined(debug):
        
        debug(logHeader & "\n" & respBody)

    callback

proc newPrimitiveAptosClient*(nodeUrl : string) : AptosClient =

    new(result)
    when not defined(js):
        
        initLock(result.clientLock)
        withLock result.clientLock:

            result.client = newAsyncHttpClient()

    result.baseUrl = parseUri(nodeUrl)

proc newFaucetClient*(nodeUrl : string) : FaucetClient =

    new(result)
    when not defined(js):
        
        initLock(result.clientLock)
        withLock result.clientLock:

            result.client = newAsyncHttpClient()

    result.baseUrl = parseUri(nodeUrl)

func getNodeInfo*(client : AptosClient) : LedgerInfo = 

    return client.nodeInfo

func setNodeInfo*(client : AptosClient, info : LedgerInfo) = 

    client.nodeInfo = info

proc close*(client : BaseClient) =
    
    when not defined(js):

        if client.isNil():

            return

        withLock client.clientLock:

            client.client.close()

        deinitLock(client.clientLock)

    else:

        discard

