source ./export.sh

export RECIPIENT=0xbc96556276d1fc405c77e0dfa68dbf5d83ec091fd354602bd17fd9d1a30ec258

sui client ptb \
--move-call sui::token::mint "<$OSAIL_TYPE>" @$TREASURY_CAP 10 \
--assign tokens \
--move-call sui::token::transfer "<$OSAIL_TYPE>" tokens @$RECIPIENT \
--assign request \
--move-call sui::token::confirm_with_policy_cap "<$OSAIL_TYPE>" @$POLICY_CAP request