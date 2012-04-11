FS        = require('fs')
Path      = require('path')
Assert    = require('assert')
Spawn     = require('child_process').spawn
Nomnom    = require('nomnom')
Framework = require('../framework')

Opts = Nomnom
    .option 'numScripts',
        full: 'num-scripts'
        required: true
        help: 'The maxmimum number of times to include jQuery.'
    .option 'script',
        default: 'jquery'
        help: 'The library to use for the script tag (jquery or knockout).'
Opts = Opts.parse()

firstHalf = "<html><head>"
secondHalf = "</head><body></script></body></html>"

scriptTag = if Opts.script == 'jquery'
    "<script src='jquery-1.7.2.js'></script>"
else
    "<script src='knockout-2.0.0.js'></script>"



results = []

runSim = (numTags) ->
    return done() if numTags > Opts.numScripts
    html = firstHalf
    for i in [0..numTags - 1]
        html += scriptTag
    html += secondHalf

    console.log('html:')
    console.log(html)

    FS.writeFileSync('../framework/apps/script-memory/index.html', html)

    try
        FS.unlinkSync('../memory/fit.log')
    catch e

    benchmark = Spawn('node',
                      ['../memory/run.js',
                       '--app=script-memory',
                       '--num-clients=10',
                       '--type=browser'],
                      {cwd: Path.resolve('..', 'memory')})
    benchmark.stderr.pipe(process.stdout)
    benchmark.stdout.pipe(process.stdout)
    benchmark.on 'exit', () ->
        console.log("Benchmark exited: #{numTags}")
        fitFile = FS.readFileSync('../memory/fit.log', 'utf8')
        FS.unlinkSync('../memory/fit.log')
        matches = /^Final\ set[\s\S]*m\s+=\s(\d+\.\d+)/gm.exec(fitFile)
        results[numTags] = matches[1]
        runSim(numTags + 1)
runSim(1)

done = () ->
    outfile = FS.createWriteStream('../results/script-memory.dat')
    for result, i in results
        continue if i == 0
        outfile.write("#{i}\t#{result}\n")
    outfile.end()
    Framework.gnuPlot "script-memory.p", () ->
        process.exit(0)

