#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
source $i_scriptDir/node_env.sh
cd $i_scriptDir/..
echo "starting master..."
i_args="examples src/server/applications" 
if [[ $# -ne 0 ]]; then
    i_args="$@"
fi
$i_coffee --nodejs "$CB_NODE_ARGS" src/master/master_main.coffee $i_args