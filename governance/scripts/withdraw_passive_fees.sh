#!/bin/bash
set -e

source ./export.sh

# Address to receive withdrawn passive fees
RECIPIENT=0xc3c7b01f09bfb204f93de85afa0a271e5bfabac31e566f7e997b9a8685f18967

# All listed token types (one per pool coin)
TOKENS=(
  "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI"
  "0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC"
  "0xd0e89b2af5e4910726fbcd8b8dd37bb79b29e5f83f7491bca830e94f7f226d29::eth::ETH"
  "0xdeeb7a4662eec9f2f3def03fb937a663dddaa2e215b8078a284d026b7946c270::deep::DEEP"
  "0x356a26eb9e012a68958082340d4c4116e7f55615cf27affcff209cf0ae544f59::wal::WAL"
  "0x7262fb2f7a3a14c888c438a3cd9b912469a58cf60f367352c46584262e8299aa::ika::IKA"
  "0xaafb102dd0902f5055cadecd687fb5b71ca82ef0e0285d90afde828ec58ca96b::btc::BTC"
  "0x7fd8aba1652c58b6397c799fd375e748e5053145cb7e126d303e0a1545fd1fec::usdz::USDZ"
  "0x375f70cf2ae4c00bf37117d0c85a2c71545e6ee05c4a5c7d282cd66a4504b068::usdt::USDT"
  "0x0041f9f9344cac094454cd574e333c4fdb132d7bcc9379bcd4aab485b2a63942::wbtc::WBTC"
  "0xf22da9a24ad027cccb5f2d496cbe91de953d363513db08a3a734d361c7c17503::LOFI::LOFI"
  "0xd1b72982e40348d069bb1ff701e634c117bb5f741f44dff91e472d3b01461e55::stsui::STSUI"
  "0x9d297676e7a4b771ab023291377b2adfaa4938fb9080b8d12430e4b108b836a9::xaum::XAUM"
  "0x41d587e5336f1c86cad50d38a7136db99333bb9bda91cea4ba69115defeb1402::sui_usde::SUI_USDE"
  "0x1d4a2bdbc1602a0adaa98194942c220202dcc56bb0a205838dfaa63db0d5497e::SAIL::SAIL"
)

# Build a single PTB with all withdraw + transfer calls
PTB_ARGS=""
for i in "${!TOKENS[@]}"; do
  TOKEN="${TOKENS[$i]}"
  PTB_ARGS+="--move-call $PACKAGE::minter::withdraw_passive_fee'<'$FULLSAIL_TOKEN_TYPE,$TOKEN'>' "
  PTB_ARGS+="@$MINTER @$DISTRIBUTE_GOVERNOR_CAP @$DISTRIBUTION_CONFIG "
  PTB_ARGS+="--assign fee_coin_$i "
  PTB_ARGS+="--transfer-objects [fee_coin_$i] @$RECIPIENT "
done

echo "Withdrawing passive fees for ${#TOKENS[@]} tokens in a single transaction..."
eval sui client ptb $PTB_ARGS
