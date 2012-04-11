FS        = require('fs')
Path      = require('path')
Assert    = require('assert')
Fork      = require('child_process').fork
Framework = require('../framework')
Nomnom    = require('nomnom')

Opts = Nomnom
    .option 'app',
        default: 'benchmark'
        help: 'Which app to run.'
    .option 'numClients',
        full: 'num-clients'
        required: true
        help: 'The number of clients to create.'
    .option 'type',
        required: true
        help: 'Which benchmark to run: "client" to benchmark additional client costs, "browser" to benchmark additional browser costs.'

Opts = Opts.parse()

serverArgs = ['--compression=false',
              '--debug',
              '--resource-proxy=false',
              '--disable-logging']

server = Framework.createServer
    app: Opts.app
    nodeArgs: ['--expose_gc']
    serverArgs: serverArgs

server.once 'ready', () ->
    server.send({type: 'gc'})
    server.send({type: 'memory'})
    server.once 'message', (msg) ->
        results = [msg.data.heapUsed / 1024]
        console.log("0: #{msg.data.heapUsed / 1024}")
        server.send({type: 'memory'})
        sharedBrowser = (Opts.type == 'client')
        
        Framework.spawnClientsInProcess
            numClients: Opts.numClients
            sharedBrowser: if Opts.type == 'client' then true else false
            serverAddress: 'http://localhost:3000'
            clientCallback: (client, cb) ->
                server.send({type: 'gc'})
                server.send({type: 'memory'})
                server.once 'message', (msg) ->
                    Assert.equal(msg.type, 'memory')
                    results[client.id] = msg.data.heapUsed / 1024
                    console.log("#{client.id}: #{ msg.data.heapUsed / 1024}")
                    cb()
            doneCallback: () ->
                prefix = if Opts.type == 'client'
                    'client-mem'
                else
                    'browser-mem'
                outfile = FS.createWriteStream("../results/#{prefix}.dat")
                for result, i in results
                    continue if Opts.type == 'client' && i == 0
                    outfile.write("#{i}\t#{result}\n")
                outfile.end()
                Framework.gnuPlot "#{prefix}.p", () ->
                    FS.renameSync(Path.resolve(__dirname, '..', 'results', "#{prefix}.png"),
                                  Path.resolve(__dirname, '..', 'results', "#{prefix}-#{Opts.numClients}-#{Opts.app}.png"))
                    FS.renameSync(Path.resolve(__dirname, '..', 'results', "#{prefix}.dat"),
                                  Path.resolve(__dirname, '..', 'results', "#{prefix}-#{Opts.numClients}-#{Opts.app}.dat"))
                    server.stop()
                    process.exit(0)
