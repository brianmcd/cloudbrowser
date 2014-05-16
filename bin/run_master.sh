#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..
echo "starting master..."
i_args="examples src/server/applications" 
if [[ $# -ne 0 ]]; then
    i_args="$@"
fi
node_modules/coffee-script/bin/coffee src/master/master_main.coffee $i_args