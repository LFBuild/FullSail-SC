source ./export.sh

# Port ID for which to update hard cap
export PORT=0x9787a95e76530f80ff8e8dd4a851a2a266b3eadcca4e6503c6d6fa18d8129ccc

# New hard cap value (u128)
# This is the maximum port capitalization in base currency
# Example: 1000000000 = 1 billion units
export NEW_HARD_CAP=101000000000

sui client ptb \
  --move-call $PACKAGE::port::update_hard_cap \
    @$PORT \
    @$VAULT_CONFIG \
    $NEW_HARD_CAP
