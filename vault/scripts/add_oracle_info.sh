source ./export.sh

# Coin type for which to add oracle info
export COIN_TYPE=0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI
export COIN_METADATA=0x9258181f5ceac8dbffb7030890243caed69a9599d2886d957a9cb7656af3bdb3

# export COIN_TYPE=0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC
# export COIN_METADATA=

# export COIN_TYPE=0x375f70cf2ae4c00bf37117d0c85a2c71545e6ee05c4a5c7d282cd66a4504b068::usdt::USDT
# export COIN_METADATA=0xda61b33ac61ed4c084bbda65a2229459ed4eb2185729e70498538f0688bec3cc

# export COIN_TYPE=0xd0e89b2af5e4910726fbcd8b8dd37bb79b29e5f83f7491bca830e94f7f226d29::eth::ETH
# export COIN_METADATA=0x89b04ba87f8832d4d76e17a1c9dce72eb3e64d372cf02012b8d2de5384faeef0

# export COIN_TYPE=0xaafb102dd0902f5055cadecd687fb5b71ca82ef0e0285d90afde828ec58ca96b::btc::BTC
# export COIN_METADATA=0x53e1cae1ad70a778d0b450d36c7c2553314ca029919005aad26945d65a8fb784

# export COIN_TYPE=0x7262fb2f7a3a14c888c438a3cd9b912469a58cf60f367352c46584262e8299aa::ika::IKA
# export COIN_METADATA=0xe9ea4723d69d1f399e88b8d890e128813eb30dc40bc012a9aca7f300332c0347

# export COIN_TYPE=0x356a26eb9e012a68958082340d4c4116e7f55615cf27affcff209cf0ae544f59::wal::WAL
# export COIN_METADATA=0xcf8a31804ae40cb3e7183fe57320f87467a7750d4fa701bca1ffbb1edd37781e

# export COIN_TYPE=0xdeeb7a4662eec9f2f3def03fb937a663dddaa2e215b8078a284d026b7946c270::deep::DEEP
# export COIN_METADATA=0x6e60b051a08fa836f5a7acd7c464c8d9825bc29c44657fe170fe9b8e1e4770c0

# Pyth price feed ID
# https://docs.pyth.network/price-feeds/core/price-feeds/price-feed-ids
# https://insights.pyth.network/price-feeds
export PRICE_FEED_ID=0x23d7315113f5b1d3ba7a83604c44b94d79f4fd69af77f804fc7f920a6dc65744

# feed price in USD
########
# SUI 0x23d7315113f5b1d3ba7a83604c44b94d79f4fd69af77f804fc7f920a6dc65744
# USDC 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a
# USDT 0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b
# ETH 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace
# BTC 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43
# IKA 0x2b529621fa6e2c8429f623ba705572aa64175d7768365ef829df6a12c9f365f4
# WAL 0xeba0732395fae9dec4bae12e52760b35fc1c5671e2da8b449c9af4efe5d54341
# DEEP 0x29bdd5248234e33bd93d3b81100b5fa32eaa5997843847e2c2cb16d7c6d9f7ff

# Maximum age of price in seconds (e.g., 60 = 60 seconds = 1 minute)
export PRICE_AGE=60

# Get coin metadata object ID (shared object)
# Coin metadata is a shared object that can be obtained via: sui client object <COIN_METADATA_ID>
# Or it's automatically resolved when using the coin type in Move calls
sui client ptb \
  --move-call $PACKAGE::pyth_oracle::add_oracle_info "<$COIN_TYPE>" \
    @$PYTH_ORACLE \
    @$VAULT_CONFIG \
    @$PYTH_STATE \
    @$COIN_METADATA \
    "vector['$PRICE_FEED_ID_HEX']" \
    $PRICE_AGE

