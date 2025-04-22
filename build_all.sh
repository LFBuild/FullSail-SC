# call this script to update all git dependencies of all packages and build them
cd ./distribution && sui move build && cd ../
cd ./integrate && sui move build && cd ../