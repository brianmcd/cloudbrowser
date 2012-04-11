set terminal png
set output "../results/client-mem.png"
set title "Memory Usage vs. Client Connections (Shared Browser)"
set size 1,0.7
set grid y
set xlabel "Client Connections"
set ylabel "Memory Usage (KB)"
f(x) = m*x + b
fit f(x) "../results/client-mem.dat" using 1:2 via m,b
set label "m = %g", m at graph 0.7, 0.6
plot "../results/client-mem.dat" using 1:2 with lines title "memory", f(x) title 'fit'
