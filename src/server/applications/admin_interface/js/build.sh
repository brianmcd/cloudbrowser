#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir

rm -rf lib
../../../../../node_modules/coffee-script/bin/coffee --output lib --compile src