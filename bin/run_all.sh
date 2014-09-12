#!/bin/bash
#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..

if [[ "X$DEBUG" == "X" ]]; then
    export DEBUG=cloudbrowser:*,－cloudbrowser:worker:browser:*,-cloudbrowser:worker:init    
fi

nohup bin/run_master.sh examples src/server/applications --disable-logging=false >master.log  2>master.err.log &

i_workers=2
if [[ "X$1" != "X" ]]; then
    i_workers=$1
fi

for (( i = 1; i <= $i_workers; i++ )); do
    echo start worker$i
    nohup bin/run_worker.sh --configPath config/worker$i >worker$i.log 2>worker$i.err.log &
done
