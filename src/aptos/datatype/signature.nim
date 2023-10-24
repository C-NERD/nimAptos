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
