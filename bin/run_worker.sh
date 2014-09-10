#!/bin/bash
# --configPath=[config path]
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..
echo "starting worker with $@"
node_modules/coffee-script/bin/coffee src/server/newbin.coffee $@