source ./export.sh

#  SAIL coin
export COIN_TYPE=0x1d4a2bdbc1602a0adaa98194942c220202dcc56bb0a205838dfaa63db0d5497e::SAIL::SAIL
export COIN_METADATA=0x09560bc6b5a8e03070791352089eed8a8c27de0849059608be7e4cd469e74756
export AGGREGATOR=0x6fad8b69ab1d9550302c610e5a0ffcb81c1e2b218ff05b6ea6cdd236b5963346

export PRICE_AGE=60

sui client ptb \
  --move-call $PACKAGE::port_oracle::add_switchboard_oracle_info "<$COIN_TYPE>" \
    @$PORT_ORACLE \
    @$VAULT_CONFIG \
    @$COIN_METADATA \
    @$AGGREGATOR \
    $PRICE_AGE

