source ./export.sh

export PACKAGE=0x6b867048c4fb8d0e2b611c281aa410273f26e3447fab1261d7968e74f70bdba4
export COIN_A=0x2::sui::SUI
export COIN_B=0x2::sui::SUI
export ID=0x198e1bc01df5f91ec116acc9eb30837b1ddb48a94580ff78c5904bb57ef21a91

sui client ptb \
--move-call $PACKAGE::liquidity_lock_v1::test_lock_position "<$COIN_A,$COIN_B>" @$ID @$CLOCK 