#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..

source $i_scriptDir/debug_env.sh


i_dir=$(pwd)
if [[ "X$1" != "X" ]]; then
    i_dir=$1
fi

# extract performance data
node_modules/coffee-script/bin/coffee benchmarks/analysis/logdata_extractor.coffee \
--directory=$i_dir

$i_scriptDir/plot_benchmark_data.sh $i_dir

$i_scriptDir/simple_log_analysis.sh