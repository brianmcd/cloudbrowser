#!/bin/bash
# --configPath=[config path]
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
source $i_scriptDir/node_env.sh
cd $i_scriptDir/..


i_node_args=$CB_NODE_ARGS

if [[ "X$CB_WORKER_DEBUG_OPTS" != "X" ]]; then
    i_node_args="$CB_NODE_ARGS $CB_WORKER_DEBUG_OPTS"
fi

echo "starting worker with $@, node parameter $i_node_args"

$i_coffee --nodejs "$i_node_args" src/server/newbin.coffee $@