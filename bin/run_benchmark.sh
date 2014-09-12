#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..

i_time=$(date "+%Y%m%d_%H%M%S")

source $i_scriptDir/debug_env.sh

i_processes=1
if [[ "X$1" != "X" ]]; then
    i_processes=$1
fi

i_logprefix=benchmark
if [[ "X$2" != "X" ]]; then
    i_logprefix=$2
fi

for (( i = 0; i < $i_processes; i++ )); do
    nohup node_modules/coffee-script/bin/coffee benchmarks/clients/client_process.coffee \
    --appinstance-count $CB_APPINS --browser-count $CB_BROWSER --client-count $CB_CLIENT --server-logging false \
    --configFile $CBCONF --app-address $CBAPP_ADDR --process-id p"$i" >$i_logprefix"_"$i".log" 2>&1 &
done
