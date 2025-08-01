#!/bin/bash

# deploy tx https://suiscan.xyz/mainnet/tx/6DcZd3cNV6nKoAyy23CHfVhBeRHbYcq2QpYTLSg6Lwui

export PACKAGE=0x320ad9d362840c2bf260c4e56fd98edaeadacf7667c7b438c4e8467248e4359f
export ADMIN_CAP=0xd6a3cd79537845c66dd612dcc09797888bc55593830e9d55d7c427bbff19344e
export CREATE_LOCKER_CAP=0xa53b21b18cf1527814047f87661f4a73c20fa53ae851fb907803d7d989c9a807
export LOCKER=0xa8a05cf7295aa9a71811cbf77659d593ad7bd825f25af5b4443ddf188773a5eb
export PERIODS_BLOCKING="vector[1,20,30]"
export PERIODS_POST_LOCKDOWN="vector[1,4,6]"

sui client ptb \
--move-call $PACKAGE::liquidity_lock_v1::init_locker \
@$ADMIN_CAP \
@$CREATE_LOCKER_CAP \
@$LOCKER \
$PERIODS_BLOCKING \
$PERIODS_POST_LOCKDOWN 