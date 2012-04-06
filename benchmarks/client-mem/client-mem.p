set terminal png
set output "client-mem.png"
set title "Memory Usage vs. Client Connections"
set size 1,0.7
set grid y
set xlabel "Client Connections"
set ylabel "Memory Usage (KB)"
plot "client-mem.dat" using 1:2 with lines title "memory"
