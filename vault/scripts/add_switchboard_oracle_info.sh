source ./export.sh

#  SAIL coin
export COIN_TYPE=0x9420f87aeaf1cd23fa613aeebe3942d1055b4a821439a24d9a703f828aa69fc0::SAIL::SAIL
export COIN_METADATA=0x2dae31c1dd6a74fc3833f73f5a1a0d85ba856051d09d614da02a475c038c362b
export AGGREGATOR=0xffc454dfd3e8543d8bb097a3bf8acfb9d721eed5820d86aa31a331291ff5af5f

export PRICE_AGE=60

sui client ptb \
  --move-call $PACKAGE::port_oracle::add_switchboard_oracle_info "<$COIN_TYPE>" \
    @$PORT_ORACLE \
    @$VAULT_CONFIG \
    @$COIN_METADATA \
    @$AGGREGATOR \
    $PRICE_AGE

