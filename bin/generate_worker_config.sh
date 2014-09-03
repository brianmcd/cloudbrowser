#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir
cd ..
# go to root
node_modules/coffee-script/bin/coffee src/master/generate_worker_config.coffee  $@