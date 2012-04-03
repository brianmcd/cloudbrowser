Path           = require('path')
Spawn          = require('child_process').spawn
Fork           = require('child_process').fork
Util           = require('util')
Assert         = require('assert')
{EventEmitter} = require('events')

class Master extends EventEmitter
    constructor: (@numClients) ->
        @workers = []
        @results = Array(@numClients)
        @setupServer()
        process.on 'exit', () =>
            @killWorkers()
            @killServer()

    @LOG_INTERVAL = 5000

    killWorkers: () ->
        worker.kill() for worker in @workers

    killServer: () ->
        @server?.kill()

    setupServer: () ->
        process.env.NODE_ENV = 'production'
        opts =
            cwd : Path.resolve(__dirname, '..', '..', '..')
            env : process.env
        @server = Spawn 'node',
            # TODO: remove one pair of '..'s once i move this out of new
            [Path.resolve(__dirname, '..', '..', '..', 'bin', 'server'),
             '--compression=false',
             '--resource-proxy=false',
             '--disable-logging',
             'examples/benchmark-app/app.js'],
             opts

        @server.stdout.setEncoding('utf8')

        @server.stdout.on 'data', (data) =>
            if /^Processing/.test(data)
                process.stdout.write(data)
            else if /^All\sservices\srunning/.test(data)
                @emit('ready')


    spawnWorker: (offset, num, callback) ->
        child = Fork(Path.resolve(__dirname, 'run_worker.js'),
                     [offset, num],
                     { cwd : process.cwd()})

        child.once 'message', (msg) =>
            Assert.equal(msg.status, 'done')
            if callback
                process.nextTick(callback)

        @workers.push(child)

        return child

    spawnWorkers: () ->
        currentWorker = 0
        numWorkers = Math.floor(@numClients / 100)
        leftovers = @numClients % 100
        if leftovers
            ++numWorkers # Need a worker for the leftovers (< 100 clients)
        else
            leftovers = 100 # Last worker will be a batch of 100
        console.log("Spawning #{numWorkers} workers.")

        workerReadyCallback = () =>
            if currentWorker == numWorkers - 1 # Last worker
                offset = @numClients - leftovers
                console.log("Worker #{currentWorker}: #{offset}-#{offset + leftovers - 1}")
                @spawnWorker offset, leftovers, () =>
                    for worker in @workers
                        worker.on 'message', (msg) =>
                            for own clientId, latency of msg
                                @results[clientId] = latency
                        worker.send({status: 'start'})
                    @startLogger()
            else
                offset = currentWorker * 100 # TODO: use constant CLIENTS_PER_WORKER
                console.log("Worker #{currentWorker}: #{offset}-#{offset + 100 - 1}")
                currentWorker++
                @spawnWorker(offset, 100, workerReadyCallback)
        workerReadyCallback()

    startLogger: () ->
        setInterval () =>
            console.log('Latencies:')
            sum = 0
            for result in @results
                if result == undefined
                    console.log("Incomplete results")
                    return
                sum += result
            avgLatency = sum / @numClients
            console.log("Avg update latency among clients: " + avgLatency)
        , Master.LOG_INTERVAL

module.exports = Master
