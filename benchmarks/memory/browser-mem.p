set terminal png
set output "../results/browser-mem.png"
set title "Memory Usage vs. Number of Browsers"
set size 1,0.7
set grid y
set xlabel "Number of Virtual Browsers"
set ylabel "Memory Usage (KB)"
plot "../results/browser-mem.dat" using 1:2 with lines title "memory"
