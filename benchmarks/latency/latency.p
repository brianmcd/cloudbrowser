set terminal png
set output "latency.png"
set title "Latency vs. Concurrent Clients"
set size 1,0.7
set grid y
set xlabel "Number of Clients"
set ylabel "Latency (ms)"
plot "latency.dat" using 1:2 with lines title "latency"