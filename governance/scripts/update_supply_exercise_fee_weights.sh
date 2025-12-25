source ./export.sh

# select sum(voting_power) from voting_results where period =84;

export EPOCH_START=1766016000
export TOTAL_SUPPLY=924905634751826   
export DISTRIBUTE_GOVERNOR_CAP=0xf5f335807046541711fbb00021927baad8798944eceb0cd4986e229def484ab6

sui client ptb \
--move-call $PACKAGE::minter::update_supply_exercise_fee_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP $EPOCH_START $TOTAL_SUPPLY @$CLOCK --gas-budget 50000000 



