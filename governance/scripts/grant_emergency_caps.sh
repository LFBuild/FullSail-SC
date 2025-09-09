source ./export.sh

export TO=0x2b0a9b6b91c79e5c6953871578dc283a5bfbf7c5d619a9314411f983f959c9db

export CLMM_PACKAGE=0xecd737da1a3bdc7826dfda093bda6032f380b0e45265166c10b8041b125980b9
export CLMM_ADMIN_CAP=0xfcc7f81f3880caf167a7d4df16ee355676636443aa02b9e84ba11d95e2bffd7b
export GLOBAL_CONFIG=0xe93baa80cb570b3a494cbf0621b2ba96bc993926d34dc92508c9446f9a05d615
export CLMM_ROLE=0

export PRICE_PACKAGE=0x93b8c8f7bcd162045d408906670278635a3490809c44a4856a687191e0042e33
export PRICE_MONITOR=0x1e2b11f45b7d059c55ebaf026b499114f7a4ed0c1fd9d9b4c76b4c759fb63900
export PRICE_SUPER_ADMIN_CAP=0xf5a39b5ab6d2f1938b0bbe202d029e312309b9914669e708b92246e686a53d86

export EMERGENCY_COUNCIL_PUBLISHER=0xedab88ffc52b4ee0a100b2e264cd485d7a6d1a13b0656350e618b2c0f5f578bd

### !!! Do not forget to transfer the emergency council cap to the TO ADDRESS

sui client ptb \
--sender @0xfed1c619fc8dd98367a0422ca9ef53c9825e2893d78dda822106d12687888fb3 --gas-coin @0xe6600100e23ccefd343837558242768b59dacca73b28132482e1b0ec6370c81b --gas-budget 100000000 --serialize-unsigned-transaction \
--move-call $CLMM_PACKAGE::config::add_role @$CLMM_ADMIN_CAP @$GLOBAL_CONFIG @$TO $CLMM_ROLE \
--move-call $VE_PACKAGE::emergency_council::create_cap @$EMERGENCY_COUNCIL_PUBLISHER @$VOTER @$MINTER @$VOTING_ESCROW \
--move-call $VE_PACKAGE::voting_escrow::create_team_cap "<$FULLSAIL_TOKEN_TYPE>" @$VOTING_ESCROW @$VOTING_ESCROW_PUBLISHER \
--assign team_cap \
--transfer-objects '[team_cap]' @$TO \
--move-call $PACKAGE::minter::grant_admin @$MINTER_PUBLISHER @$TO \
--move-call $PACKAGE::minter::grant_distribute_governor @$MINTER_PUBLISHER @$TO
