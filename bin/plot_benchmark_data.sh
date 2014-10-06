#!/bin/bash
i_rootdir=$(cd "$(dirname "$0")/.."; pwd)
i_eventpg="$i_rootdir"/benchmarks/analysis/eventprocess.gp
i_sysmonpg="$i_rootdir"/benchmarks/analysis/sysmon.gp

i_workdir=$i_rootdir
if [[ "X$1" != "X" ]]; then
    i_workdir=$1
fi

cd $i_workdir

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
    cd $i_workdir/$1
    echo plot in $i_workdir/$1
    for f in $(ls *eventProcess*.dat); do
        i_png="${f%.*}".png
        gnuplot -e "filename='$f'" $i_eventpg > $i_png
        echo write file $i_png
    done
    for f in $(ls *sysmon*.dat); do
        i_png="${f%.*}".png
        gnuplot -e "filename='$f'" $i_sysmonpg > $i_png
        echo write file $i_png
    done
}


for d in ${i_datadirs[@]}; do
    plot_dir $d
done