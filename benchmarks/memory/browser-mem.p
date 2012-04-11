set terminal png
set output "../results/browser-mem.png"
set title "Memory Usage vs. Number of Browsers"
set size 1,0.7
set grid y
set xlabel "Number of Virtual Browsers"
set ylabel "Memory Usage (KB)"
f(x) = m*x + b
fit f(x) "../results/browser-mem.dat" using 1:2 via m,b
set label "m = %g", m at graph 0.7, 0.6
plot "../results/browser-mem.dat" using 1:2 with lines title "memory", f(x) title 'fit'
