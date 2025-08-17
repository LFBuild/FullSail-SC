source export.sh

export MINTER=0xb145981a29c220d8ac1523a512f423eeedce0b71279c7aca0ec005642a1f7431
export METHOD=0xc16f3f27459c77dc77a080b765b3d3492b56b6b3e2f1baf322b1f45da7f7dbba::minter::mint_test_sail
export MINTER_PUBLISHER=0xc8f1a6f24d265297be826001677ac5d2209070f7f3b8d17f7ccbd075c289a3f3

python3 distribution_script_generator.py --method $METHOD --token-type $COIN_TYPE --minter $MINTER --publisher $MINTER_PUBLISHER --max-addresses 250 airdrop.xlsx