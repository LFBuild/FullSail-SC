source ./export.sh

export TOTAL_REWARD_AMOUNT=6000000000000 # set the total reward amount
export COIN_ID=0x26430670292f183db8f8573ad424ec71350cf02765fa46cee6ff22fedc7a06b1

export REWARD_TOKEN_TYPE=0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI

sui client call \
  --package $PACKAGE \
  --module rewarder_script \
  --function deposit_reward \
  --type-args $REWARD_TOKEN_TYPE \
  --args \
    $GLOBAL_CONFIG \
    $REWARDER_GLOBAL_VAULT \
    "[$COIN_ID]" \
    $TOTAL_REWARD_AMOUNT