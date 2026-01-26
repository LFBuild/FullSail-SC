source ./export.sh

export EXERCISE_FEE_COIN=0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC
export AMOUNT=4675895131

sui client ptb \
--move-call $PACKAGE::minter::distribute_exercise_fee_to_reward "<$FULLSAIL_TOKEN_TYPE,$EXERCISE_FEE_COIN>" @$MINTER @$VOTER @$MINTER_ADMIN_CAP @$DISTRIBUTION_CONFIG $AMOUNT @$CLOCK