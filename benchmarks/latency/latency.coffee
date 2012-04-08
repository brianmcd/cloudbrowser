FS        = require('fs')
Assert    = require('assert')
Fork      = require('child_process').fork
Framework = require('../framework')
LockstepClient = require('../framework/client/lockstep_client')

# TODO: make latency configurable.
Opts = require('nomnom')
    .option 'app',
        default: 'benchmark'
        help: 'Which app to run.'
    .option 'startNumClients',
        full: 'start-clients'
        required: true
        help: 'The starting number of clients to create.'
    .option 'endNumClients',
        full: 'end-clients'
        required: true
        help: 'The ending number of clients to create.'
    .option 'stepSize',
        full: 'step-size'
        required: true
        help: 'The step size of the number of clients between each iteration'
Opts = Opts.parse()

Opts.startNumClients += Opts.stepSize if Opts.startNumClients == 0

event =
    type: 'click', target: 'node12', bubbles: true, cancelable: true,
    view: null, detail: 1, screenX: 2315, screenY: 307, clientX: 635,
    clientY: 166, ctrlKey: false, shiftKey: false, altKey: false,
    metaKey: false, button: 0

aggregateResults = {}

runSim = (numClients) ->
    console.log("Running simulation for #{numClients}.")
    server = Framework.createServer
        app: Opts.app
        serverArgs: ['--compression=false',
                     '--resource-proxy=false',
                     '--simulate-latency=true',
                     '--disable-logging']
        printEventsPerSec: true
    server.once 'ready', () ->
        results = {}
        numResults = {}
        finishedClients = {}
        clients = null
        resultEE = Framework.spawnClientsMultiProcess
            numClients: numClients
            sharedBrowser: false
            clientClass: LockstepClient
            clientData:
                event: event
            doneCallback: (_clients) ->
                clients = _clients
        resultEE.on 'Result', (id, latency) ->
            #console.log("Result: #{id}=#{latency}")
            results[id] = latency
            return if finishedClients[id]
            numResults[id] = numResults[id] + 1 || 0
            if numResults[id] == 5
                console.log("#{id} is finished")
                finishedClients[id] = true
            if Object.keys(finishedClients).length == numClients
                client.kill() for client in clients
                server.stop () ->
                    sum = 0
                    for own id, result of results
                        sum += result
                    aggregateResults[numClients] = sum / numClients
                    numClients += Opts.stepSize
                    if numClients <= Opts.endNumClients
                        runSim(numClients)
                    else
                        done()
runSim(Opts.startNumClients)

done = () ->
    outfile = FS.createWriteStream('../results/latency.dat')
    console.log("Results:")
    for own key, val of aggregateResults
        console.log("\t#{key}: #{val}")
        outfile.write("#{key}\t#{val}\n")
    outfile.end()
    Framework.gnuPlot('latency.p')
