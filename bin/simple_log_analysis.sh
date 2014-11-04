#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)

i_baseDir=$(cd "$i_scriptDir/..";pwd)

if [[ "X$1" != "X" ]]; then
    i_baseDir=$1
fi

cd $i_baseDir

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
    echo $line open inital html count
    grep opened $line | wc -l
done
