source ./export.sh

export COIN_TYPE=0x1018b0843a724fd966b37f018bbc489918b6594144451cf4b481d392c9a0a463::token_a::TOKEN_A
export COIN_ID=0x5f74257bcefb22a1e8ff05dac62ae5836b49cfe57c59f678c8052b192abfee46
export START_TIME_MS=1777580940135

sui client ptb \
  --split-coins @$COIN_ID "[30000000]" \
  --assign new_coins \
  --move-call $PACKAGE::airdrop::new "<$COIN_TYPE>" new_coins.0 vector[245,221,124,42,107,205,16,76,192,14,193,44,171,5,199,84,161,94,136,171,174,70,37,95,239,114,133,159,148,138,188,250] $START_TIME_MS @$CLOCK \
  --assign airdrop \
  --move-call  sui::transfer::public_share_object "<$PACKAGE::airdrop::Airdrop<$COIN_TYPE>>" airdrop