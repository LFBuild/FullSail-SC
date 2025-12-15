source ./export.sh

# Role values:
# 0 = ROLE_PROTOCOL_FEE_CLAIM
# 1 = ROLE_REINVEST
# 2 = ROLE_REBALANCE
# 3 = ROLE_POOL_MANAGER
# 4 = ROLE_ORACLE_MANAGER

export MEMBER_ADDRESS=0xe28ed0b47bc4561cf70b0a2b058c530320f6ed109eebe0e8b59196990751961c
export ROLE=1

sui client ptb \
  --move-call $PACKAGE::vault_config::add_role @$VAULT_CONFIG @$ADMIN_CAP @$MEMBER_ADDRESS $ROLE

