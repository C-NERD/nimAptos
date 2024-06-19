import pkg / [bcs]

import ../api/aptosclient
import ../movetypes/[address]

type

    MultiSigCreationMessage* = object

        chain_id* : uint8
        account_address* : Address
        sequence_number*, num_signatures_required* : uint64
        owners* : seq[Address]

proc initMultiSigCreationMessage*(account_address : Address, client : AptosClient, owners : seq[Address], 
    sequence_number, num_signatures_required : uint64) : MultiSigCreationMessage =

    return MultiSigCreationMessage(
        chain_id : client.getNodeInfo().chain_id,
        account_address : account_address,
        sequence_number : sequence_number,
        owners : owners,
        num_signatures_required : num_signatures_required
    )

proc serialize*(data : MultiSigCreationMessage) : HexString =

    result.add bcs.serialize(data.chain_id)
    result.add address.serialize(data.account_address)
    result.add bcs.serialize(data.sequence_number)

    for val in serializeUleb128(uint32(len(data.owners))): ## serialize owners length

        result.add bcs.serialize(val)

    for owner in data.owners:

        result.add address.serialize(owner)

    result.add bcs.serialize(data.num_signatures_required)

proc deSerialize*(data : var HexString) : MultiSigCreationMessage =

    result.chain_id = bcs.deSerialize[uint8](data)
    result.account_address = address.deSerialize(data)
    result.sequence_number = bcs.deSerialize[uint64](data)

    let ownersLen = deSerializeUleb128(data)
    for _ in 0..<ownersLen:

        result.owners.add address.deSerialize(data)

    result.num_signatures_required = bcs.deSerialize[uint64](data)

