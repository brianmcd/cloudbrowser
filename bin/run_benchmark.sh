#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..

i_time=$(date "+%Y%m%d%H%M%S")

source $i_scriptDir/debug_env.sh
# print all the env variables set for test
env | grep CB

i_processes=1
if [[ "X$1" != "X" ]]; then
    i_processes=$1
fi

i_prefix=benchmark"$i_time"
if [[ "X$2" != "X" ]]; then
    i_prefix=$2
fi

echo start $i_logprefix with $i_processes benchmark processes

for (( i = 0; i < $i_processes; i++ )); do
    i_group=p"$i"
    i_logfile="$i_prefix"_client_"$i_group"".log"
    nohup node_modules/coffee-script/bin/coffee benchmarks/clients/client_process.coffee \
    --appinstance-count $CB_APPINS --browser-count $CB_BROWSER --client-count $CB_CLIENT --server-logging false \
    --configFile $CB_CONF --app-address $CBAPP_ADDR --process-id $i_group >$i_logfile 2>&1 &
    echo benchmark process $i_group log to $i_logfile
done
