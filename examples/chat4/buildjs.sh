#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)

cd $i_scriptDir
i_root_dir=$(cd ../../; pwd) 

i_coffee=$i_root_dir/node_modules/coffee-script/bin/coffee

date

cd $i_scriptDir/js
$i_coffee --output lib --compile src