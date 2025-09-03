source export.sh

export USD_TYPE=0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC
export METADATA=0x69b7a7c3c200439c1b5f3b19d7d495d5966d5f08de66c69276152f8db3992ec6

sui client ptb \
--move-call $PACKAGE::minter::whitelist_usd "<$FULLSAIL_TOKEN_TYPE,$USD_TYPE>" @$MINTER @$DISTRIBUTION_CONFIG @$MINTER_ADMIN_CAP true 


