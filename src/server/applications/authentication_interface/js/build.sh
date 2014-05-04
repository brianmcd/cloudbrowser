#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir

../../../../../node_modules/coffee-script/bin/coffee --compile *.coffee
