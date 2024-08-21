#                    NimAptos
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## implementation of move multisig_creation_message

import pkg / [bcs]

import ../api/aptosclient
import ../movetypes/[address]

type

    MultiSigCreationMessage* = object

        chain_id*: uint8
        account_address*: Address
        sequence_number*, num_signatures_required * : uint64
        owners*: seq[Address]

proc initMultiSigCreationMessage*(account_address: Address, client: AptosClient,
        owners: seq[Address],
    sequence_number, num_signatures_required: uint64): MultiSigCreationMessage =

    return MultiSigCreationMessage(
        chain_id: client.getNodeInfo().chain_id,
        account_address: account_address,
        sequence_number: sequence_number,
        owners: owners,
        num_signatures_required: num_signatures_required
    )

proc toBcsHook*(data: MultiSigCreationMessage, output: var HexString) =

    output.add serialize(data.chain_id)
    toBcsHook(data.account_address, output)
    output.add serialize(data.sequence_number)

    for val in serializeUleb128(uint32(len(data.owners))): ## serialize owners length

        output.add serialize(val)

    for owner in data.owners:

        toBcsHook(owner, output)

    output.add serialize(data.num_signatures_required)

proc fromBcsHook*(data: var HexString, output: var MultiSigCreationMessage) =

    output.chain_id = deSerialize[uint8](data)
    fromBcsHook(data, output.account_address)
    output.sequence_number = deSerialize[uint64](data)

    let ownersLen = deSerializeUleb128(data)
    for _ in 0..<ownersLen:

        var owner: Address
        fromBcsHook(data, owner)
        output.owners.add owner

    output.num_signatures_required = deSerialize[uint64](data)

