#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementation for transaction signatures

## std imports
import std / [bitops]
from std / strformat import fmt

## pkg imports
import pkg / [jsony]

type

    SignatureType* = enum

        SingleSignature = "ed25519_signature"
        MultiSignature = "multi_ed25519_signature"
        MultiAgentSignature = "multi_agent_signature"

    Signature* = object

        case `type`* : SignatureType
        of SingleSignature:

            public_key*, signature* : string

        of MultiSignature:

            public_keys*, signatures* : seq[string]
            bitmap* : string ## array of size 32 containing bits of signatures. 1 for Nth signature if present
            ## 0 for Nth signature if absent
            threshold* : int ## the minimum number of public keys required for this signature to be
            ## authorized

        of MultiAgentSignature:

            secondary_signer_addresses* : seq[string]
            sender* : ref Signature
            secondary_signers* : seq[Signature]

const MAX_SIGNATURES_SUPPORTED = 32

proc createBitMap*(bits : seq[int]) : array[4, byte] =

    let firstBitInByte = 128'u8
    var dupCheck : seq[int]
    for pos in 0..<len(bits):
        
        if bits[pos] >= MAX_SIGNATURES_SUPPORTED:

            raise newException(CatchableError, fmt"signature cannot be larger than {MAX_SIGNATURES_SUPPORTED}")
        
        elif bits[pos] in dupCheck:

            raise newException(CatchableError, "duplicate bits detected")

        elif pos > 0:

            if bits[pos] <= bits[pos - 1]:

                raise newException(CatchableError, "the bits should be sorted in ascending order")

        dupCheck.add bits[pos]

        let byteOffset = int(bits[pos] div 8)
        result[byteOffset] = bitor(result[byteOffset], (rotateRightBits(firstBitInByte, (bits[pos] mod 8))))

proc dumpHook*(s : var string, v : Signature) =

    case v.`type`

    of SingleSignature:
        
        s.add "{\"type\" : \"" & $SingleSignature & "\","
        s.add "\"public_key\" : " & toJson(v.public_key) & ","
        s.add "\"signature\" : " & toJson(v.signature) & "}"

    of MultiSignature:
        
        s.add "{\"type\" : \"" & $MultiSignature & "\","
        s.add "\"public_keys\" : " & toJson(v.public_keys) & ","
        s.add "\"signatures\" : " & toJson(v.signatures) & ","
        s.add "\"bitmap\" : " & toJson(v.bitmap) & ","
        s.add "\"threshold\" : " & $v.threshold & "}"

    of MultiAgentSignature:

        var sec_signers_addrs = "["
        let addrLen = len(v.secondary_signer_addresses)
        for pos in 0..<addrLen:

            sec_signers_addrs.add toJson(v.secondary_signer_addresses[pos])
            if pos < addrLen - 1:

                sec_signers_addrs.add ","

        sec_signers_addrs.add "]"

        let sender = toJson(v.sender[])
        
        var sec_signers = "["
        let signersLen = len(v.secondary_signers)
        for pos in 0..<signersLen:

            sec_signers.add toJson(v.secondary_signers[pos])
            if pos < signersLen - 1:

                sec_signers.add ","

        sec_signers.add "]"
        
        ## fix multi agent transaction json serialization
        ## and add deserialization function
        s.add "{\"type\" : \"" & $MultiAgentSignature & "\","
        s.add "\"sender\" : " & sender & ","
        s.add "\"secondary_signer_addresses\" : " & sec_signers_addrs & "," 
        s.add "\"secondary_signers\" : " & sec_signers & "}"

