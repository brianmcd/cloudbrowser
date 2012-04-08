set terminal png
set output "../results/latency.png"
set title "Latency vs. Concurrent Clients"
set size 1,0.7
set grid y
set xlabel "Number of Clients"
set ylabel "Latency (ms)"
plot "../results/latency.dat" using 1:2 with lines title "latency"
