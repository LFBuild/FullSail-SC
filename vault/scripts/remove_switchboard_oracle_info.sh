source ./export.sh

#  SAIL coin
export COIN_TYPE=0x9420f87aeaf1cd23fa613aeebe3942d1055b4a821439a24d9a703f828aa69fc0::SAIL::SAIL

sui client ptb \
  --move-call $PACKAGE::port_oracle::remove_switchboard_oracle_info "<$COIN_TYPE>" \
    @$PORT_ORACLE \
    @$VAULT_CONFIG

