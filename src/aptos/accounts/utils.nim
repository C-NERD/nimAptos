##
## This module implements RefAptosAccount and RefMultiSigAccount types
## and required helper functions for the types

when defined(js):

    {.fatal : "js backend is not implemented for account utils module".}

import std / [asyncdispatch, jsonutils]
from std / strutils import toHex
from std / re import match, re
from std / json import `$`, getStr, `[]`, parseJson
from std / options import some
from std / strformat import fmt

## project imports
import ../ed25519/ed25519
import ../movetypes/address
import ../api/[utils, aptosclient, nodetypes]

type

    InvalidSeed* = object of ValueError

    AccountCreationError* = object of CatchableError

    AptosAccount = ref object of RootObj

        address* : Address
        authentication_key* : string 
        sequence_number*, guid_creation_num* : uint64
    
    RefAptosAccount* = ref object of AptosAccount

        seed, publicKey, privateKey : string

    RefMultiSigAccount* = ref object of AptosAccount
        
        accounts* : seq[RefAptosAccount]
        last_executed_sequence_number*, next_sequence_number*, num_signatures_required* : uint64

proc isValidSeed*(seed : string) : bool = match seed, re"^((0x)?)([A-z]|[0-9]){64}$"

proc isPriKey*(key : string) : bool = match key, re"^((0x)?)([A-z]|[0-9]){128}$"

proc getPublicKey*(account : RefAptosAccount) : string = "0x" & account.publicKey

proc getPrivateKey*(account : RefAptosAccount) : string = "0x" & account.privateKey

proc getPublicKey*(account : RefMultiSigAccount) : string = 

    result.add "0x" 
    for account in account.accounts:

        result.add account.publicKey

    result.add toHex(account.num_signatures_required, 2)

proc accountExists*(client : AptosClient, address : string) : Future[bool] {.async.} =

    let resp = await executeModuleView[tuple[anon1 : string]](
        client,
        ViewRequest[tuple[anon1 : string]]( ## just give the field any random name
            function : "0x1::account::exists_at",
            type_arguments : @[],
            arguments : some((anon1 : address))
        )
    )
    return jsonTo(parseJson(resp), seq[bool])[0]

## initialization procs for type RefAptosAccount and RefMultiSigAccount
proc newAccount*(address, seed : string) : 
    RefAptosAccount =
    ## The seed is your 32 bytes | 64 character private key
    
    if not isValidSeed(seed):

        raise newException(InvalidSeed, fmt"seed {seed} is invalid")
    
    let keypair = getKeyPair(seed)
    return RefAptosAccount(
        address : initAddress(address),
        publicKey : keypair.pubkey,
        privateKey : keypair.prvkey,
        seed : seed 
    ) 

proc newMultiSigAccount*(accounts : seq[RefAptosAccount], address : string) : RefMultiSigAccount =
    
    return RefMultiSigAccount(
        address : initAddress(address),
        accounts : accounts
    )

