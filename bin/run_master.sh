#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
source $i_scriptDir/node_env.sh
cd $i_scriptDir/..
i_args="examples src/server/applications" 
if [[ $# -ne 0 ]]; then
    i_args="$@"
fi

i_node_args=$CB_NODE_ARGS

if [[ "X$CB_MASTER_DEBUG_OPTS" != "X" ]]; then
    i_node_args="$CB_NODE_ARGS $CB_MASTER_DEBUG_OPTS"
fi

echo "starting master, node parameter $i_node_args"

$i_coffee --nodejs "$i_node_args" src/master/master_main.coffee $i_args