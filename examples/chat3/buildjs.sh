#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)

cd $i_scriptDir
i_coffee_dir=$(cd ../../; pwd) 

i_coffee=$i_coffee_dir/node_modules/coffee-script/bin/coffee

#echo $i_coffee
date

cd $i_scriptDir/js
$i_coffee --compile *.coffee

cd $i_scriptDir/model
$i_coffee --compile *.coffee