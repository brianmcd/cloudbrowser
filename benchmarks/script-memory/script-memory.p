set terminal png
set output "../results/script-memory.png"
set title "Memory Usage vs. Number of jQuery Script Tags"
set size 1,0.7
set grid y
set xlabel "Number of jQuery Script Tags"
set ylabel "Memory Usage (KB)"
f(x) = m*x + b
fit f(x) "../results/script-memory.dat" using 1:2 via m,b
set label "m = %g", m at graph 0.7, 0.6
plot "../results/script-memory.dat" using 1:2 with lines title "memory", f(x) title 'fit'
