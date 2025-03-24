source ./export.sh

export METADATA_ID=0x1a6cd1c7f6694b4a36c2bc9e5b64ce24cf146e640b99de45398173c5902d8245

sui client ptb \
--move-call sui::transfer::public_freeze_object "<sui::coin::CoinMetadata<$FULLSAIL_TOKEN_TYPE>>" @$METADATA_ID