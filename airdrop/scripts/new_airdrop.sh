source ./export.sh

export COIN_TYPE=0x1018b0843a724fd966b37f018bbc489918b6594144451cf4b481d392c9a0a463::token_a::TOKEN_A
export COIN_ID=0x5f74257bcefb22a1e8ff05dac62ae5836b49cfe57c59f678c8052b192abfee46
export START_TIME_MS=1777617408094

sui client ptb \
  --split-coins @$COIN_ID "[30000000000]" \
  --assign new_coins \
  --move-call $PACKAGE::airdrop::new "<$COIN_TYPE>" new_coins.0 vector[188,193,100,23,96,82,189,31,212,91,5,184,238,241,114,218,178,136,149,103,141,56,109,124,37,231,206,156,155,83,45,149] $START_TIME_MS @$CLOCK \
  --assign airdrop \
  --move-call  sui::transfer::public_share_object "<$PACKAGE::airdrop::Airdrop<$COIN_TYPE>>" airdrop