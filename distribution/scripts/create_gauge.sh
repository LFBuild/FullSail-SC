source ./export.sh

export COIN_A=0xf058f11e52c92ddf9b747ad1152e1915c077c93607fcfdb7d81afcff4a48e122::deep_test::DEEP_TEST
export COIN_B=0xbea898c10cbdce78040ca666da2f598703a2f3cd8bbe56c416a22756583f8b30::sui_test::SUI_TEST
export POOL=0x142d332b033e182e7281c29e8d6d5ba89a125c61c8bfcd3650cd99ab875941bd
export GAUGE_BASE_EMISSIONS=10000000000

sui client ptb \
--move-call $PACKAGE::minter::create_gauge "<$COIN_A,$COIN_B,$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$CREATE_CAP @$MINTER_ADMIN_CAP @$VOTING_ESCROW @$POOL $GAUGE_BASE_EMISSIONS @$CLOCK \
--assign gauge \
--move-call sui::transfer::public_share_object "<$ORIGINAL_PACKAGE::gauge::Gauge<$COIN_A,$COIN_B>>" gauge