#!/bin/bash
declare -a i_datadirs
i=0
for f in $(ls); do
    if [[ $(expr "$f" : '.*_data') != 0 ]]; then
        i_datadirs[i]=$f
        i=$((i+1))
    fi
done

echo plot data "in" ${i_datadirs[*]}

plot_dir(){
    # do plot in $1
}


for d in ${i_datadirs[@]}; do
    plot_dir d
done