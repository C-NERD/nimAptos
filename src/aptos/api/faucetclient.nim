#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementation for faucet client node procs

## std imports
import std / [uri, httpcore]
from std / json import parseJson, JsonParsingError
from std / jsonutils import jsonTo

## project imports
import utils

export ApiError, InvalidApiResponse, FaucetClient, newFaucetClient, close

method faucetFund*(client: FaucetClient, address: string, amount: int): Future[
        seq[string]] {.async, gcsafe, base.} =
    ## This function is only meant to be called when using the devnet
    ## returns sequence of transaction hash

    callNode client, "mint", HttpPost, @[("amount", $amount), ("address",
            address)], ():

        try:

            {.cast(gcsafe).}:

                return jsonTo(parseJson(respBody), typeof(result))

        except JsonParsingError:

            raise newException(InvalidApiResponse, respBody)

