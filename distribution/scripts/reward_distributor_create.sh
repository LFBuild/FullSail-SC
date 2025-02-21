source ./export.sh

sui client ptb \
--move-call $PACKAGE::reward_distributor::create "<$FULLSAIL_TOKEN_TYPE>" @$REWARD_DISTRIBUTOR_PUBLISHER @0x6 \
--assign reward_distributor_and_cap \
--move-call sui::transfer::public_share_object "<$PACKAGE::reward_distributor::RewardDistributor<$FULLSAIL_TOKEN_TYPE>>" reward_distributor_and_cap.0 \
--transfer-objects '[reward_distributor_and_cap.1]' @$ADDR
