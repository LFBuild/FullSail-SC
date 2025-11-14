source ./export.sh

export COIN_TYPE=0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI
export NEW_SLIPPAGE=50

sui client ptb \
  --move-call $PACKAGE::vault_config::set_swap_slippage "<$COIN_TYPE>" @$VAULT_CONFIG $NEW_SLIPPAGE