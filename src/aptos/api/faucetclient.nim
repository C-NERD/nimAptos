## std imports
import std / [uri, httpcore]
import pkg / [jsony]
#from std / strutils import split, parseInt

## project imports
import utils

export ApiError, InvalidApiResponse, FaucetClient, newFaucetClient, close

#[when defined(debug):
    
    import std / logging

    var logger = newConsoleLogger(fmtStr = "$time :: $levelname -> ", useStderr = true)]#

method faucetFund*(client : FaucetClient, address : string, amount : int) : Future[seq[string]] {.async, gcsafe, base.} =
    ## This function is only meant to be called when using the devnet
    ## returns sequence of transaction hash
    
    callNode client, "mint", HttpPost, @[("amount", $amount), ("address", address)], ():

        try:
            
            {.cast(gcsafe).}:

                return respBody.fromJson(typeof(result))

        except JsonError:

            raise newException(InvalidApiResponse, respBody)

