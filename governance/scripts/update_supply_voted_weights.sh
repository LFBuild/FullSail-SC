source ./export.sh
source ./pools/pool_wbtc_usdc.sh

# select p.name, pool_id, sum(final_voting_power) from voting_results join pools as p on p.id=voting_results.pool_id where period =83 GROUP BY pool_id, p.name;  and pool_id = '0x17bac48cb12d565e5f5fdf37da71705de2bf84045fac5630c6d00138387bf46a';

export EPOCH_START=1761782400





export TOTAL_SUPPLY=13816041706875
export DISTRIBUTE_GOVERNOR_CAP=0xf5f335807046541711fbb00021927baad8798944eceb0cd4986e229def484ab6

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK --gas-budget 50000000 


#  name    |                              pool_id                               |       sum       
# ------------+--------------------------------------------------------------------+-----------------
#  ALKIMI/SUI | 0x17bac48cb12d565e5f5fdf37da71705de2bf84045fac5630c6d00138387bf46a |     71969003761
#  WAL/SUI    | 0x20e2f4d32c633be7eac9cba3b2d18b8ae188c0b639f3028915afe2af7ed7c89f |   9578590657000
#  IKA/SUI    | 0xa7aa7807a87a771206571d3dd40e53ccbc395d7024def57b49ed9200b5b7e4e5 | 126391363415686
#  MMT/USDC   | 0x4c46799974cde779100204a28bc131fa70c76d08c71e19eb87903ac9fedf0b00 |     32876473152
#  SAIL/USDC  | 0x038eca6cc3ba17b84829ea28abac7238238364e0787ad714ac35c1140561a6b9 |   6567977342450
#  DEEP/SUI   | 0xd0dd3d7ae05c22c80e1e16639fb0d4334372a8a45a8f01c85dac662cc8850b60 |   4257795440829
#  ETH/USDC   | 0x90ad474a2b0e4512e953dbe9805eb233ffe5659b93b4bb71ce56bd4110b38c91 |  20786582500081
#  wBTC/USDC  | 0x195fa451874754e5f14f88040756d4897a5fe4b872dffc4e451d80376fa7c858 |  13816041706875
#  USDT/USDC  | 0xb41cf6d7b9dfdf21279571a1128292b56b70ad5e0106243db102a8e4aea842c7 |    304686418349
#  SUI/USDC   | 0x7fc2f2f3807c6e19f0d418d1aaad89e6f0e866b5e4ea10b295ca0b686b6c4980 |  42761993741018
#  USDZ/USDC  | 0xe676d09899c8a4f4ecd3e4b9adac181f3f2e1e439db19454cacce1b4ea5b40f4 |   1282987335499