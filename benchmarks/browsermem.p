set terminal png
set output "browsermem.png"
set title "Memory Usage vs. Number of Browsers"
set size 1,0.7
set grid y
set xlabel "Number of Virtual Browsers"
set ylabel "Memory Usage (KB)"
plot "browsermem.dat" using 1:2 with lines title "memory"
