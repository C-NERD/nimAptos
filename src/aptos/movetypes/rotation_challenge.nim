#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementation of move rotation proof challenge

import pkg / [bcs]
import address

type

    RotationProofChallenge* = object

        sequence_number: uint64
        originator, current_auth_key: Address
        new_public_key: HexString

proc initRotationProofChallenge*(sequence_number: uint64, originator,
        current_auth_key: Address,
        new_public_key: HexString): RotationProofChallenge =

    return RotationProofChallenge(
        sequence_number: sequence_number,
        originator: originator,
        current_auth_key: current_auth_key,
        new_public_key: new_public_key
    )

proc toBcsHook*(data: RotationProofChallenge, output: var HexString) =

    output.add serialize(data.sequence_number)
    toBcsHook(data.originator, output)
    toBcsHook(data.current_auth_key, output)
    output.add serialize(data.new_public_key)

proc fromBcsHook*(data: var HexString, output: var RotationProofChallenge) =

    output.sequence_number = deSerialize[uint64](data)
    fromBcsHook(data, output.originator)
    fromBcsHook(data, output.current_auth_key)
    output.new_public_key = deSerialize[HexString](data)
