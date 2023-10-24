type

    Event* = object

        `type`*, version*, sequence_number* : string
        guid* : tuple[creation_number, account_address : string]
        data* : tuple[
            epoch, hash, height, previous_block_votes_bitvec, proposer, round, time_microseconds : string, 
            failed_proposer_indices : seq[int]
        ]
