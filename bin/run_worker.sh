#!/bin/bash
# --configPath=[config path]
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
source $i_scriptDir/node_env.sh
cd $i_scriptDir/..
echo "starting worker with $@"
$i_coffee --nodejs "$CB_NODE_ARGS" src/server/newbin.coffee $@