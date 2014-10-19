# Gnuplot script file for plotting data
reset
set terminal png
set samples 10000
set   autoscale                        # scale axes automatically
unset log                              # remove any log-scaling
unset label                            # remove any previous labels
set xtic auto                          # set xtics automatically
set ytic auto                          # set ytics automatically
set title "Event Process Plot ".filename
set xlabel "Time(s)"


set ylabel "Throughput"
set y2label "Latency"

set ytics nomirror in
set y2tics nomirror

set yrange [0:*]
set y2range [0:*]

# filename is a parameter
plot filename u ($1 / 1000):2 t 'Throughput' with lines axes x1y1,\
"" u ($1 / 1000):4 t 'Latency' with lines axes x1y2
#
