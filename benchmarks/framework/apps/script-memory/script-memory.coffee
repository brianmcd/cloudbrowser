FS        = require('fs')
Path      = require('path')
Assert    = require('assert')
Spawn     = require('child_process').spawn
Nomnom    = require('nomnom')

Opts = Nomnom
    .option 'numScripts',
        full: 'num-scripts'
        required: true
        help: 'The maxmimum number of times to include jQuery.'
Opts = Opts.parse()

firstHalf = "<html><head>"
secondHalf = "</head><body></body></html>"
jQueryTag = "<script src='jquery-1.7.2.js'></script>"

runSim = (numTags) ->
    html = firstHalf
    for i in [0..numTags - 1]
        html += jQueryTag
    html += secondHalf

    console.log('html:')
    console.log(html)

    FS.writeFileSync('index.html', html)

    try
        FS.unlinkSync('../memory/fit.log')
    catch e

    benchmark = Spawn('node', ['../memory/run.js',
                             '--app=benchmarks/script-memory/index.html',
                             '--num-clients=100',
                             '--type=browser'], {cwd: Path.resolve('..', 'memory')})

    benchmark.stderr.pipe(process.stdout)
    benchmark.stdout.pipe(process.stdout)
    benchmark.on 'exit', () ->
        console.log("Benchmark exited: #{numTags}")
        fitFile = FS.readFileSync('../memory/fit.log')
        FS.unlinkSync('../memory/fit.log')
        matches = /^Final\ set.*m\s+=\s(\d+\.\d+).*^b\s+=\s(\d+\.\d+)/.exec(fitFile)
        console.log(matches)
        console.log(matches[1])
        console.log(matches[2])
    
runSim(1)
