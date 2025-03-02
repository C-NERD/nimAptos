#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## This module implements code for the pure ed25519 cryptography

when defined(js):

    {.fatal: "js backend not implemented for ed25519 module".}

# stdlib imports
import std / [sysrand]
from std / strutils import toLowerAscii #, toUpperAscii, parseHexStr, toHex
#from std / random import randomize, rand

# third party imports
from pkg / libsodium / sodium import crypto_sign_seed_keypair,
        crypto_sign_ed25519_sk_to_seed,
     crypto_sign, crypto_sign_open, hex2bin, bin2hex
from pkg / libsodium / sodium_sizes import crypto_sign_bytes

template shedPrefix(value: var string) =

    if toLowerAscii(value[0..1]) == "0x":

        value = value[2..<len(value)]

proc randomSeed*(): array[32, byte] = assert urandom(result), "failed to generate seed"

proc getSeed*(prikey: string): string = crypto_sign_ed25519_sk_to_seed(prikey)

proc getKeyPair*(seed: string): tuple[pubkey, prvkey: string] =

    var seed = seed
    shedPrefix(seed)

    #seed = parseHexStr(seed)
    seed = hex2bin(seed)
    result = crypto_sign_seed_keypair(seed)
    #result.pubkey = toLowerAscii(toHex(result.pubkey))
    #result.prvkey = toLowerAscii(toHex(result.prvkey))
    result.pubkey = toLowerAscii(bin2hex(result.pubkey))
    result.prvkey = toLowerAscii(bin2hex(result.prvkey))

template sign(prvkey, data: string, code: untyped): untyped =

    let
        signedMsg = crypto_sign(prvkey, data)
        #signature {.inject.} = toLowerAscii(toHex(signedMsg[
        #        0..<crypto_sign_bytes()]))
        signature {.inject.} = toLowerAscii(bin2hex(signedMsg[
                0..<crypto_sign_bytes()]))

    code

proc signHex*(prvkey, data: string): string =

    var
        prvkey = prvkey
        data = data
    shedPrefix(prvkey)
    shedPrefix(data)

    #prvkey = parseHexStr(prvkey)
    #data = parseHexStr(data)
    prvkey = hex2bin(prvkey)
    data = hex2bin(data)
    sign(prvkey, data):

        result = signature

proc verifyHex*(pubkey, signature, data: string): bool =

    var
        pubkey = pubkey
        signature = signature
        data = data
    shedPrefix(pubkey)
    shedPrefix(signature)
    shedPrefix(data)

    var signedMsg = signature & data

    #pubkey = parseHexStr(pubkey)
    #signedMsg = parseHexStr(signedMsg)
    pubkey = hex2bin(pubkey)
    signedMsg = hex2bin(signedMsg)

    let msg = crypto_sign_open(pubkey, signedMsg)
    #return msg == parseHexStr(data)
    return msg == hex2bin(data)

