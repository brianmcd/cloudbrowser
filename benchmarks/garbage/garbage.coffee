Assert    = require('assert')
Framework = require('../framework')

Opts = require('nomnom')
    .option 'app',
        default: 'benchmark'
        help: 'Which app to run'
    .option 'numBrowsers'
        full: 'num-browsers'
        help: 'The number of browsers to create.'
        required: true
    .option 'iterations'
        help: 'The number of times to create/destroy num-browsers browsers.'
        default: 1
Opts = Opts.parse()

server = Framework.createServer
    nodeArgs: ['--expose-gc']
    serverArgs: ['--compression=false',
                 '--resource-proxy=false',
                 '--disable-logging',
                 '--knockout',
                 'examples/chat2/app.js']

outstandingBrowsers = {}

server.on 'message', (msg) ->
    switch msg.type
        when 'browserCreated'
            outstandingBrowsers[msg.id] = true
        when 'browserCollected'
            delete outstandingBrowsers[msg.id]
        when 'memory'
            MB = msg.data.heapUsed / (1024 * 1024)
            console.log("Finishing heap size: #{MB} MB.")
            process.exit(0)

server.once 'ready', () ->
    iterate = (i) ->
        console.log("Starting iteration #{i}...")
        # We're done.  Request server's memory usage and our message
        # handler will print it and exit.
        return server.send({type: 'memory'}) if i >= Opts.iterations

        Framework.spawnClientsInProcess
            numClients: Opts.numBrowsers
            sharedBrowser: false
            serverAddress: 'http://localhost:3000'
            clientCallback: (client, cb) ->
                console.log("[iteration #{i}] created client: #{client.id}")
                cb()
            doneCallback: () ->
                for own id of outstandingBrowsers
                    server.send({type: 'closeBrowser', id: id})
                server.send({type: 'gc'})
                setTimeout () ->
                    Assert.equal(Object.keys(outstandingBrowsers).length, 0)
                    console.log("Iteration #{i}: all browsers reclaimed.")
                    iterate(i + 1)
                , 1000
    iterate(0)
