#!/bin/bash
#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..

bin/run_master.sh examples src/server/applications --disable-logging=false &

i_workers=2
if [[ "X$1" != "X" ]]; then
    i_workers=$1
fi

for (( i = 1; i <= $i_workers; i++ )); do
    echo start worker$i
    bin/run_worker.sh --configPath config/worker$i &
done