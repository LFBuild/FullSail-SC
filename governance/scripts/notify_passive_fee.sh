source ./export.sh

export COIN=0x5f74257bcefb22a1e8ff05dac62ae5836b49cfe57c59f678c8052b192abfee46

sui client ptb \
--split-coins @$COIN "[100000000000]"\
--assign fee_coin \
--move-call $PACKAGE::minter::notify_passive_fee "<$FULLSAIL_TOKEN_TYPE,$PASSIVE_FEE_COIN>" @$MINTER @$DISTRIBUTE_GOVERNOR_CAP @$DISTRIBUTION_CONFIG @$PASSIVE_FEE_DISTRIBUTOR fee_coin.0 @$CLOCK
