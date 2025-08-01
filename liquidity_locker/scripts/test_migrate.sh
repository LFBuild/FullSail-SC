source ./export.sh

export PACKAGE=0x99001472f26abd7e5e7c02624d0e92840dd568b72816db01c1cc1a73426bc431
export COIN_A=0x2::sui::SUI
export COIN_B=0x2::sui::SUI
export LOCKER_V1=0xefd5043c8e79efd1be8e049846317507bed55dae0f9413a8017a2bfb2300edda
export LOCKER_V2=0x99c8eccaf96be8f219f4878646646d448a084d1c97d4ec997e6ea4380044ba14
export LOCK_POSITION_V1=0xac0d136263d1331410f5add130dddf01bc8f7ee59e87b654f624185c54f7f7e5


sui client ptb \
--move-call $PACKAGE::liquidity_lock_v2::test_migrate "<$COIN_A,$COIN_B>" @$LOCKER_V1 @$LOCKER_V2 @$LOCK_POSITION_V1 @$CLOCK 