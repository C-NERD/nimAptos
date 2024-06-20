## 
## This module implements procs to work with both RefAptosAccount and RefMultiSigAccount

when defined(js):

    {.fatal: "js backend is not implemented for account module".}

## std imports
import std / [json, asyncdispatch]
from std / strutils import parseBiggestUInt, parseInt, toHex
from std / times import epochTime

## third party imports
import pkg / [sha3]
#import pkg / nimcrypto / utils as cryptoutils

import ./[aptos_account, multisig_account, multiagent_account]
import ./utils as accountutils
import ../utils
import ../api/[aptosclient]
import ../aptostypes/[transaction]
import ../movetypes/address
from ../aptostypes/payload/payload import TransactionPayload

export accountutils, aptos_account, multisig_account, multiagent_account

when defined(debug):

    import std / [logging]

proc refresh*(account: var RefAptosAccount | var RefMultiSigAccount,
        client: AptosClient) {.async.} =

    when account is RefAptosAccount:

        try:

            let resource = await client.getAccountResource($account.address, "0x1::account::Account")
            account.sequence_number = parseBiggestUInt(getStr(resource.data[
                    "sequence_number"]))
            account.authentication_key = getStr(resource.data["authentication_key"])
            account.guid_creation_num = parseBiggestUInt(getStr(resource.data[
                    "guid_creation_num"]))

        except ApiError: ## ignore if can't refresh

            when defined(debug):

                error getCurrentExceptionMsg()

            else:

                discard

    elif account is RefMultiSigAccount:

        try:

            let resources = await client.getAccountResources($account.address) #, )
            for resource in resources:

                case resource.`type`

                of "0x1::multisig_account::MultisigAccount":

                    account.last_executed_sequence_number = parseBiggestUInt(
                            getStr(resource.data[
                            "last_executed_sequence_number"]))
                    account.next_sequence_number = parseBiggestUInt(getStr(
                            resource.data["next_sequence_number"]))
                    account.num_signatures_required = parseBiggestUInt(getStr(
                            resource.data["num_signatures_required"]))

                of "0x1::account::Account":

                    account.sequence_number = parseBiggestUInt(getStr(
                            resource.data["sequence_number"]))
                    account.authentication_key = getStr(resource.data["authentication_key"])
                    account.guid_creation_num = parseBiggestUInt(getStr(
                            resource.data["guid_creation_num"]))

                else:

                    continue

        except ApiError:

            when defined(debug):

                error getCurrentExceptionMsg()

            else:

                discard

proc accountBalanceApt*(account: RefAptosAccount | RefMultiSigAccount,
        client: AptosClient): Future[float] {.async.} =

    let resource = await client.getAccountResource($account.address, "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>")
    return parseInt(getStr(resource.data["coin"]["value"])).toApt()

proc buildTransaction*[T: TransactionPayload](account: RefAptosAccount |
        RefMultiSigAccount, client: AptosClient, max_gas_amount = -1;
        gas_price = -1; txn_duration: int64 = -1): Future[RawTransaction[T]] {.async.} =
    ## params :
    ##
    ## account          -> account to build transaction for
    ## max_gas_amount   -> maximum amount of gas that can be sent for this transaction
    ## gas_price        -> price in octa unit per gas
    ## txn_duration     -> amount of time in seconds till transaction timeout
    var
        duration = txn_duration
        sequenceNumber: uint64
    if duration < 0:

        duration = 18000 ## set to 5 hours

    await account.refresh(client)
    when account is RefAptosAccount:

        sequenceNumber = account.sequence_number

    elif account is RefMultiSigAccount:

        sequenceNumber = account.sequence_number #account.last_executed_sequence_number

    result = RawTransaction[T](
        chain_id: client.getNodeInfo().chain_id,
        sender: $account.address,
        sequence_number: $sequenceNumber,
        expiration_timestamp_secs: $(int64(epochTime()) + duration)
    )

    if max_gas_amount >= 0:

        result.max_gas_amount = $max_gas_amount

    if gas_price >= 0:

        result.gas_unit_price = $gasPrice

