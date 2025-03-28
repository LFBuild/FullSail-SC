source ./export.sh

export ADDR=0xedd5ec373fa5b1f5c903cc1b6b49bb96013af6346475ff6ffe743ed88a94c1cb

sui client ptb \
--move-call $PACKAGE::allow_list::allowed_add "<$OSAIL_TYPE>" @$POLICY_CAP @$POLICY @$ADDR