source ./export.sh

export STAKED_POSITION_ID="0x102df5407d03e2814c9de29c6752b9f695a07650ed4fee0327ec98430d10e014"

sui client ptb \
--move-call $PACKAGE::gauge::position_id @$STAKED_POSITION_ID --gas-budget 50000000 