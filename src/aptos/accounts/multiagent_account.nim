import pkg / [sha3]
import pkg / nimcrypto / utils as cryptoutils

import ../aptostypes/transaction
import ../movetypes/address
import ../aptostypes/authenticator/[authenticator]
from ../aptostypes/payload/payload import TransactionPayload

when defined(debug):

    import logging

proc preHashMultiAgentTxn*(): string =

    var ctx: SHA3
    let bcsTxn = "APTOS::RawTransactionWithData"
    sha3_init(ctx, SHA3_256)
    sha3_update(ctx, bcsTxn, len(bcsTxn))

    let preHash = sha3_final(ctx)
    result = cryptoutils.toHex(preHash, true)
    when defined(debug):

        debug(result)

proc multiAgentSignTransaction*[T: TransactionPayload](
    sender_sig: Authenticator, secondary_signers: seq[Authenticator],

signer_addrs: seq[Address], transaction: RawTransaction[T]): SignedTransaction[T] =

    result = toSignedTransaction[T](transaction)
    result.authenticator = initAuthenticator(
        MultiAgentEd25519,
        initMultiAgentEd25519Authenticator(
            signer_addrs, sender_sig, secondary_signers
        )
    )
