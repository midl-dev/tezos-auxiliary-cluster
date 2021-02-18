#!/bin/sh

set -e
set -x

bin_dir="/usr/local/bin"

data_dir="/var/run/tezos"
node_dir="$data_dir/node"
node_data_dir="$node_dir/data"
node="$bin_dir/tezos-node"

cat /var/run/tezos/node/data/config.json
if  [ "$(cat /var/run/tezos/node/data/config.json  | jq -r '.shell.history_mode')" == "archive" ]; then
    echo "Already in archive mode, no need to reconstruct"
else
    echo "Reconstructing archive storage from full mode"
    exec "${node}" reconstruct --data-dir ${node_data_dir} --network $TEZOS_NETWORK
fi
