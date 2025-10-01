source ./export.sh

export EXERCISE_FEE_COIN=0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC

sui client ptb \
--move-call $PACKAGE::minter::distribute_operations "<$FULLSAIL_TOKEN_TYPE,$EXERCISE_FEE_COIN>" @$MINTER @$MINTER_ADMIN_CAP @$DISTRIBUTION_CONFIG