# call this script to update all git dependencies of all packages and build them
cd ./price_monitor && sui move build && cd ../
cd ./ve && sui move build && cd ../
cd ./distribution && sui move build && cd ../
cd ./liquidity_locker && sui move build && cd ../
cd ./integrate && sui move build && cd ../