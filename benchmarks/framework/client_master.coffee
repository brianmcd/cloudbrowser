Path           = require('path')
Fork           = require('child_process').fork
Assert         = require('assert')
{EventEmitter} = require('events')

class ClientMaster extends EventEmitter
    constructor: (@numClients, @sendMessages) ->
        @numWorkers = Math.floor(@numClients / 100)
        @numWorkers++ if @numClients % 100 != 0
        @workers = []
        @results = Array(@numClients)
        process.setMaxListeners(0)
        process.on('exit', () => @killWorkers())
        @spawnWorkers()

    killWorkers: () ->
        worker.kill() for worker in @workers

    spawnWorkers: () ->
        clientsLeft = @numClients
        console.log("Spawning #{@numWorkers} workers.")
        workerReadyCallback = () =>
            if clientsLeft == 0
                return @finalizeWorkers()
            offset = @numClients - clientsLeft
            numClientsToMake = Math.min(100, clientsLeft)
            console.log("Worker: #{offset}-#{offset + numClientsToMake - 1}")
            clientsLeft -= numClientsToMake
            @spawnWorker(offset, numClientsToMake, workerReadyCallback)
        workerReadyCallback()

    spawnWorker: (offset, num, callback) ->
        worker = Fork Path.resolve(__dirname, 'run_client_worker.js'),
                      [offset, num, @sendMessages.toString()],
                      {cwd : process.cwd()}
        @workers.push(worker)
        # Note: using this 'fn' because I'm seeing spurious empty 'message'
        # callbacks from the worker process, so we can't just use 'once'.
        fn = (msg) =>
            if msg.status == 'done'
                worker.removeListener('message', fn)
                callback()
        worker.on('message', fn)

    finalizeWorkers: () ->
        for worker in @workers
            worker.on 'message', (msg) =>
                for own clientId, latency of msg
                    @results[clientId] = latency
            worker.send({status: 'start'})
            @emit('start')

module.exports = ClientMaster
