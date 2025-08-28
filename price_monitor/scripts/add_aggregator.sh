source ./export.sh

export AGGREGATOR=0xffc454dfd3e8543d8bb097a3bf8acfb9d721eed5820d86aa31a331291ff5af5f
export POOL=0xcd24a573e09c3aaf67850ee3c6511e4508d8faf897eb12ab38b580c894b5d976

sui client ptb \
--make-move-vec '<sui::object::ID>' "[@$POOL]" \
--assign pool_ids \
--move-call $PACKAGE::price_monitor::add_aggregator @$MONITOR @$AGGREGATOR pool_ids "vector[9]" "vector[6]"