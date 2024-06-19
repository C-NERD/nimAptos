import pkg / [bcs]
import address

type

    RotationProofChallenge* = object

        sequence_number : uint64
        originator, current_auth_key : Address
        new_public_key : HexString

proc initRotationProofChallenge*(sequence_number : uint64, originator, current_auth_key : Address, new_public_key : HexString) : RotationProofChallenge =

    return RotationProofChallenge(
        sequence_number : sequence_number,
        originator : originator,
        current_auth_key : current_auth_key,
        new_public_key : new_public_key
    )

proc serialize*(data : RotationProofChallenge) : HexString =

    result.add bcs.serialize(data.sequence_number)
    result.add address.serialize(data.originator)
    result.add address.serialize(data.current_auth_key)
    result.add bcs.serialize(data.new_public_key)

proc deSerialize*(data : var HexString) : RotationProofChallenge =

    result.sequence_number = bcs.deSerialize[uint64](data)
    result.originator = address.deSerialize(data)
    result.current_auth_key = address.deSerialize(data)
    result.new_public_key = bcs.deSerialize[HexString](data)
