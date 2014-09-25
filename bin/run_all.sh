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

i_master_log=$i_prefix"_master.log"

nohup bin/run_master.sh examples src/server/applications --disable-logging=false >$i_master_log  2>&1 &
echo master log write to $i_master_log


for (( i = 1; i <= $i_workers; i++ )); do
    i_worker_log="$i_prefix"_worker"$i".log
    nohup bin/run_worker.sh --configPath config/worker$i >$i_worker_log 2>&1 &
    echo worker$i log write to $i_worker_log
done
