#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..
echo "try out cloudbrowser on a single machine"
node_modules/coffee-script/bin/coffee src/master/single_machine_runner.coffee examples src/server/applications