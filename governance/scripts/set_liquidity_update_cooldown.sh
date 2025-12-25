source ./export.sh

# Set liquidity update cooldown in seconds
# Usage: ./set_liquidity_update_cooldown.sh <cooldown_seconds>
# Example: ./set_liquidity_update_cooldown.sh 600  (sets 10 minute cooldown)

export COOLDOWN=0  # Default to 600 seconds (10 minutes) if not provided

sui client ptb \
--move-call $PACKAGE::minter::set_liquidity_update_cooldown "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$MINTER_ADMIN_CAP @$DISTRIBUTION_CONFIG $COOLDOWN

