source ./export.sh

export AMOUNT=1000000000000

sui client ptb \
--move-call "sui::coin::mint" "<0xbea898c10cbdce78040ca666da2f598703a2f3cd8bbe56c416a22756583f8b30::sui_test::SUI_TEST>" @0x4152116b6393841e680a0553f7f69c52e9799686a3f9cc09d6f0d37d594f922c $AMOUNT \
--assign new_coins \
--transfer-objects "[new_coins]" @0x7f2bc2cadcead6dc4706c3259ff0e55fcfd6afd5b9134a0978b0ad22453ac486