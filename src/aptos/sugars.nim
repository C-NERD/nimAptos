#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## This module implements syntatic sugars for building, signing and executing multiple
## transaction types
## All importable procs except validateGasFees are templates, so don't forget to import the template's dependency
## packages. They are
## - ./accounts/account
## - ./aptostypes/transactions
## - ./aptostypes/payload/payload
## - ./api/aptosclient
## - ./pkg/bcs

## NOTE :: pass the -d:nodeSerialization option while compiling to encode all transactions
## directly on the aptos node
## If this option is not passed all transactions will be encoded locally

## std imports
import std / [asyncdispatch]
from std / strutils import toLowerAscii

## project imports
import ./api/aptosclient
import ./accounts/account
from ./aptostypes/transaction import RawTransaction
from ./aptostypes/payload/payload import TransactionPayload

var DEFAULT_MAX_GAS_AMOUNT* = 10000 ## change this to what you want the default max gas amount to be

## extension procs to node api
template singleSign*[T: TransactionPayload](account: RefAptosAccount,
        client: AptosClient, transaction: RawTransaction[T],
        encoding: string = ""): untyped =

    var signedTransaction: SignedTransaction[T]
    when defined(nodeSerialization):

        ## encode transaction on the node
        signedTransaction = await signTransaction[T](account, client,
                transaction, encoding)

    else:

        signedTransaction = signTransaction[T](account, transaction, encoding)

    signedTransaction

template multiSign*[T: TransactionPayload](account: RefMultiSigAccount,
        client: AptosClient, transaction: RawTransaction[T],
        encoding: string = ""): untyped =

    var signedTransaction: SignedTransaction[T]
    when defined(nodeSerialization):

        ## encode transaction on the node
        signedTransaction = await multiSignTransaction[T](account, client,
                transaction, encoding)

    else:

        signedTransaction = multiSignTransaction[T](account, transaction, encoding)

    signedTransaction

proc validateGasFees*(client: AptosClient, max_gas_amount,
        gas_price: int64): Future[tuple[max_gas_amount,
        gas_price: int64]] {.async.} =
    ## gas_price is in octa

    var
        max_gas_amount = max_gas_amount
        gas_price = gas_price

    if max_gas_amount < 0:

        max_gas_amount = DEFAULT_MAX_GAS_AMOUNT

    if gas_price < 0:

        let gasInfo = await client.estimateGasPrice()
        gas_price = gasInfo.prioritized_gas_estimate

    return (max_gas_amount, gas_price)

template transact*[T: TransactionPayload](account: RefAptosAccount |
        RefMultiSigAccount, client: AptosClient, payload: T, max_gas_amount_arg,
        gas_price_arg, txn_duration_arg: int64): untyped =
    ## required variables
    ## client : (AptosClient)
    ## account : account initiating transaction (RefAptosAccount | RefMultiSigAccount)
    ## max_gas_amount : maximum gas amount permitted (int64)
    ## gas_price : gas price to be used for transaction (int64)
    ## txn_duration : duration for transaction timeout in seconds(int64)
    ##
    ## injects:
    ## var transaction : RawTransaction
    ## var signedTransaction (for other tmpl called)
    ##
    ## sets result to SignedTransaction

    var fees = await validateGasFees(client, max_gas_amount_arg, gas_price_arg)
    var transaction = await buildTransaction[T](account, client,
            fees.max_gas_amount, fees.gas_price, txn_duration_arg)
    transaction.payload = payload

    var signedTransaction: SignedTransaction[T]
    when account is RefAptosAccount:

        signedTransaction = singleSign[T](account, client, transaction, "")

    elif account is RefMultiSigAccount:

        signedTransaction = multiSign[T](account, client, transaction, "")

    await submitTransaction[T](client, signedTransaction)

template multiAgentTransact*[T: TransactionPayload](account: RefAptosAccount |
        RefMultiSigAccount, single_sec_signers: seq[RefAptosAccount],
        multi_sec_signers: seq[RefMultiSigAccount], client: AptosClient,
        payload: T, max_gas_amount_arg, gas_price_arg,
        txn_duration_arg: int64): untyped =
    ## like transact tmpl, but for multiagent transactions
    ## required variables
    ## client : (AptosClient)
    ## sender : sender's account object (RefAptosAccount | RefMultiSigAccount)
    ## singleSigners : seq of signers seq[RefAptosAccount]
    ## multiSigners : seq of signers seq[RefMultiSigAccount]
    ## signers : seq of all signers address seq[string]
    ## NOTE :: this template assumes that the first account in accounts is the sender.
    ## max_gas_amount : maximum gas amount permitted (int64)
    ## gas_price : gas price to be used for transaction (int64)
    ## txn_duration : duration for transaction timeout in seconds(int64)

    var fees = await validateGasFees(client, max_gas_amount_arg, gas_price_arg)
    var transaction = await buildTransaction[T](account, client,
            fees.max_gas_amount, fees.gas_price, txn_duration_arg)
    transaction.payload = payload

    var multiAgentTransaction = toMultiAgentRawTransaction[T](transaction)
    for signer in single_sec_signers:

        multiAgentTransaction.secondary_signers.add $signer.address

    for signer in multi_sec_signers:

        multiAgentTransaction.secondary_signers.add $signer.address

    var encodedTransaction: string
    when defined(nodeSerialization):

        encodedTransaction = await client.encodeSubmission(multiAgentTransaction)

    else:

        encodedTransaction = "0x" & preHashMultiAgentTxn() & toLowerAscii(
                $serialize(multiAgentTransaction))

    var signedTransaction: SignedTransaction[T]
    when account is RefAptosAccount:

        signedTransaction = singleSign[T](account, client, transaction, encodedTransaction)

    elif account is RefMultiSigAccount:

        signedTransaction = multiSign[T](account, client, transaction, encodedTransaction)

    var
        signerAddresses: seq[Address]
        signerSignatures: seq[Authenticator]
    for signer in single_sec_signers:

        let singleSignedTxn = singleSign[T](signer, client, transaction, encodedTransaction)

        signerAddresses.add signer.address
        signerSignatures.add singleSignedTxn.authenticator

    for signer in multiSigners:

        let multiSignedTxn = multiSign[T](signer, client, transaction, encodedTransaction)

        signerAddresses.add signer.address
        signerSignatures.add multiSignedTxn.authenticator

    signedTransaction = multiAgentSignTransaction[T](
        signedTransaction.authenticator,
        signerSignatures,
        signerAddresses,
        transaction
    )
    await submitTransaction[T](client, signedTransaction)

