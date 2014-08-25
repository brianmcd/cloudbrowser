{WorkerConfigGenerator} = require './config'

if process.argv.length < 4
    console.log "Usage #{process.argv[1]} [config path] [worker count]"
    process.exit(1)


opts = {
    configPath : process.argv[2]
    workerCount : process.argv[3]
}

new WorkerConfigGenerator(opts, (err, gen)->
    gen.generate()
)
