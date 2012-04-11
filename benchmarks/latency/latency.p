set terminal png
set output "../results/latency.png"
set title "Latency vs. Concurrent Clients"
set size 1,0.7
set grid y
set xlabel "Number of Clients"
set ylabel "Latency (ms)"
f(x) = m*x + b
fit f(x) "../results/latency.dat" using 1:2 via m,b
set label "m = %g", m at graph 0.7, 0.6
plot "../results/latency.dat" using 1:2 with lines title "latency", f(x) title 'fit'
