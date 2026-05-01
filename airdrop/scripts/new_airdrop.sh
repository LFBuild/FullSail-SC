source ./export.sh

export COIN_TYPE=0x1018b0843a724fd966b37f018bbc489918b6594144451cf4b481d392c9a0a463::token_a::TOKEN_A
export COIN_ID=0x5f74257bcefb22a1e8ff05dac62ae5836b49cfe57c59f678c8052b192abfee46
export START_TIME_MS=1777639913766

sui client ptb \
  --split-coins @$COIN_ID "[20000000000]" \
  --assign new_coins \
  --move-call $PACKAGE::airdrop::new "<$COIN_TYPE>" new_coins.0 vector[176,166,158,18,24,232,91,106,26,42,245,36,243,244,68,166,84,196,12,156,241,201,238,242,170,68,240,93,218,71,36,54] $START_TIME_MS @$CLOCK \
  --assign airdrop \
  --move-call  sui::transfer::public_share_object "<$PACKAGE::airdrop::Airdrop<$COIN_TYPE>>" airdrop