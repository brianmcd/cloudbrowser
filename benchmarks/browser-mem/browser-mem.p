set terminal png
set output "browser-mem.png"
set title "Memory Usage vs. Number of Browsers"
set size 1,0.7
set grid y
set xlabel "Number of Virtual Browsers"
set ylabel "Memory Usage (KB)"
plot "browser-mem.dat" using 1:2 with lines title "memory"
