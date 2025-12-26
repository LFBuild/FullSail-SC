source ./export.sh

# Role values:
# 0 = ROLE_PROTOCOL_FEE_CLAIM
# 1 = ROLE_REINVEST
# 2 = ROLE_REBALANCE
# 3 = ROLE_POOL_MANAGER
# 4 = ROLE_ORACLE_MANAGER

export MEMBER_ADDRESS=0xc2c7a6d112b07a68e6ecf8c5e6275c007589d40a87debbba155efc134ba2b6e1
export ROLE=3

sui client ptb \
  --move-call $PACKAGE::vault_config::add_role @$VAULT_CONFIG @$ADMIN_CAP @$MEMBER_ADDRESS $ROLE

