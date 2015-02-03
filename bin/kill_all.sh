#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..

# the processes are started by coffee, be careful here.
# we only want to send signal to the actual node processes
i_node=$(which node)

i_flag=""
if [[ "X$1" != "X" ]]; then
    i_flag="-"$1
fi

for i in $(ps ax|grep $i_node| grep -e newbin -e master| grep -v grep | awk '{split($0,a," "); print a[1]}'); do
    echo kill $i_flag $i
    kill $i_flag $i
done

echo "kill complete"

echo

ps ax|grep node