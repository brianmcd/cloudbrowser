set terminal png
set output "../results/client-mem.png"
set title "Memory Usage vs. Client Connections"
set size 1,0.7
set grid y
set xlabel "Client Connections"
set ylabel "Memory Usage (KB)"
plot "../results/client-mem.dat" using 1:2 with lines title "memory"
