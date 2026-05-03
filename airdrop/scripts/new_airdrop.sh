source ./export.sh

export COIN_TYPE=0x1018b0843a724fd966b37f018bbc489918b6594144451cf4b481d392c9a0a463::token_a::TOKEN_A
export COIN_ID=0x5f74257bcefb22a1e8ff05dac62ae5836b49cfe57c59f678c8052b192abfee46
export START_TIME_MS=1777809959089

sui client ptb \
  --split-coins @$COIN_ID "[44000000000]" \
  --assign new_coins \
  --move-call $PACKAGE::airdrop::new "<$COIN_TYPE>" new_coins.0 vector[62,131,15,225,84,207,237,220,103,149,80,127,228,188,110,90,0,69,160,207,81,103,168,183,22,53,115,7,82,6,199,97] $START_TIME_MS @$CLOCK \
  --assign airdrop \
  --move-call  sui::transfer::public_share_object "<$PACKAGE::airdrop::Airdrop<$COIN_TYPE>>" airdrop