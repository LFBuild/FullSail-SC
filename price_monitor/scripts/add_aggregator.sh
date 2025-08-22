source ./export.sh

export AGGREGATOR=0xffc454dfd3e8543d8bb097a3bf8acfb9d721eed5820d86aa31a331291ff5af5f
export POOL=0xecd2248bff3ebe159e236076324c70f15df24c50ec81a8213bc91b1db6664fc1

sui client ptb \
--make-move-vec '<sui::object::ID>' "[@$POOL]" \
--assign pool_ids \
--move-call $PACKAGE::price_monitor::add_aggregator @$MONITOR @$AGGREGATOR pool_ids