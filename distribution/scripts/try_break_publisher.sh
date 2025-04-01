source ./export.sh

#fullsale contracts have

export WRONG_PUBLISHER=0x065d0eaa9c8337788be71980a9ce26e68a39a0885ecbff808fdfa116dc9ff906
export WHO=0xedd5ec373fa5b1f5c903cc1b6b49bb96013af6346475ff6ffe743ed88a94c1cb
export WRONG_ADMIN_CAP=0xfee22c0f0f1f565fbb192c21be2c555979a7361a79402658198215bb7c1dea9a
export NEW_TEAM_WALLET=0x7f2bc2cadcead6dc4706c3259ff0e55fcfd6afd5b9134a0978b0ad22453ac486

sui client ptb \
--move-call $PACKAGE::minter::set_team_wallet "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$WRONG_ADMIN_CAP @$NEW_TEAM_WALLET