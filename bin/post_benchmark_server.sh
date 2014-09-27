#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..

for line in $(ls *worker*.log); do
    echo $line createBrowser count
    grep createBrowser $line | wc -l
done

for line in $(ls *master*.log); do
    echo $line register appInstance count
    grep "register appInstance" $line | wc -l
done

for line in $(ls *client*.log); do
    # some processing maybe
done