#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..

i_interval=30
i_killServerInterval=20

while [[ true ]]; do
    i_nodes=$(ps ax | grep node | grep -v grep)
    if [[ "X$i_nodes" == "X" ]]; then
        echo $(date) "No nodes program running. Kill server after $i_killServerInterval s"
        sleep $i_killServerInterval
        echo $(date) "kill server"
        ssh rnikola.cs.vt.edu "killall node"
        break
    else
        echo $(date) "Node program running"
    fi
    sleep $i_interval
done


echo $(date) "Done"