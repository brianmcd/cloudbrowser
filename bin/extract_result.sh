#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..


source $i_scriptDir/debug_env.sh
source $i_scriptDir/node_env.sh

i_dir=$(pwd)
if [[ "X$1" != "X" ]]; then
    i_dir=$1
fi

$i_coffee benchmarks/analysis/result_extractor.coffee --directory=$i_dir