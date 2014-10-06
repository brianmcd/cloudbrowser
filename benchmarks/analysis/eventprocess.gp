# Gnuplot script file for plotting data in file "force.dat"
reset
set terminal png

set   autoscale                        # scale axes automatically
unset log                              # remove any log-scaling
unset label                            # remove any previous labels
set xtic auto                          # set xtics automatically
set ytic auto                          # set ytics automatically
set title "Event Process Plot"
set xlabel "Time(ms)"
set ylabel "Latency"
# filename is a parameter
plot filename u 1:2 t 'rate' w linespoints,\
"" u 1:4 t 'latency' w points
#