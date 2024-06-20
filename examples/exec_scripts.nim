## This example runs a move script from this project https://github.com/C-NERD/salesRecord.git
{.define: debug.}

import std / [asyncdispatch, logging]
from std / strformat import fmt
from std / os import `/`, parentDir, getEnv
from std / strutils import toHex
import aptos
import aptos / sugars

let logger = newConsoleLogger(fmtStr = "[$levelname] -> ")
addHandler(logger)

const SCRIPT = block:

    #[let file = open(parentDir(currentSourcePath()) / "movescripts/script.mv", fmRead)
    var script : seq[byte]
    discard file.readBytes(script, 0, file.getFileSize() - 1)
    file.flushFile()
    file.close()]#

    #fromBytes(script) ## return hex of script
    var data = slurp(currentSourcePath().parentDir() / "movescripts/script.mv")
    data = toHex(data)
    data

proc customTxn(account: RefAptosAccount, client: AptosClient,
        payload: ScriptPayload): Future[SubmittedTransaction[
        ScriptPayload]] {.async.} =

    return transact[ScriptPayload](account, client, payload, -1, -1, -1)

info "running move script ..."
let
    client = newAptosClient("https://fullnode.devnet.aptoslabs.com/v1")
    account1 = newAccount(
        getEnv("APTOS_ADDRESS1"),
        getEnv("APTOS_SEED1")
    )
    payload = ScriptPayload(
        code: MoveScriptBytecode(
           bytecode: Script,
           abi: MoveFunction(
                name: "main",
                visibility: "public",
                is_entry: true,
                is_view: false,
                generic_type_params: @[],
                params: @["&signer", "address"],
                `return`: @[]
        )
    ),
        type_arguments: @[],
        arguments: @[sArg initAddress(getEnv("APTOS_ADDRESS2"))]
    ) ## Only need to define MoveFunction because of requests are json requests
      ## In the future with bcs requests, this will not be necessary
    txn = waitFor customTxn(account1, client, payload)

notice fmt"succesfully ran movescript at {txn.hash}"
client.close()
