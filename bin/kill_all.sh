#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..

for i in $(ps ax|grep node| grep -e newbin -e master| grep -v grep | awk '{split($0,a," "); print a[1]}'); do
    echo kill $i
    kill $i
done

echo "kill complete"

echo

ps ax|grep node