#!/bin/bash

i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..

i_time=$(date "+%Y%m%d%H%M%S")

source $i_scriptDir/debug_env.sh

i_workers=2
if [[ "X$1" != "X" ]]; then
    i_workers=$1
fi

i_prefix="cb"$i_time

if [[ "X$2" != "X" ]]; then
    i_prefix=$2
fi

i_apps="examples src/server/applications"

if [[ "X$3" != "X" ]]; then
    i_apps=$3
fi

if [[ "X$CB_OPTS" == "X" ]]; then
    export CB_OPTS="--disable-logging=false"
fi

i_debugopts=""
getDebugOpts(){
    i_debugopts=""
    if [[ "X$CB_DEBUG" == "Xtrue" ]]; then
        # help me random number god
        i_debugport=$(jot -r 1  9000 65000)
        echo "debug worker at $i_debugport"
        i_debugopts="--debug=$i_debugport"
    fi
}

i_master_log=$i_prefix"_master.log"
getDebugOpts
export CB_MASTER_DEBUG_OPTS=$i_debugopts

nohup bin/run_master.sh $i_apps $CB_OPTS >$i_master_log  2>&1 &
echo master log write to $i_master_log , debug setting $CB_MASTER_DEBUG_OPTS


for (( i = 1; i <= $i_workers; i++ )); do
    i_worker_log="$i_prefix"_worker"$i".log
    getDebugOpts
    export CB_WORKER_DEBUG_OPTS=$i_debugopts
    nohup bin/run_worker.sh --configPath config/worker$i >$i_worker_log 2>&1 &
    echo worker$i log write to $i_worker_log , debug setting $CB_WORKER_DEBUG_OPTS
done
