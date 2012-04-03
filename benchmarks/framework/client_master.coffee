Path           = require('path')
Fork           = require('child_process').fork
Assert         = require('assert')
{EventEmitter} = require('events')

class ClientMaster extends EventEmitter
    constructor: (@numClients) ->
        @numWorkers = Math.floor(@numClients / 100)
        @numWorkers++ if @numClients % 100 != 0
        @workers = []
        @results = Array(@numClients)
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
                      [offset, num],
                      {cwd : process.cwd()}
        @workers.push(worker)
        worker.once 'message', (msg) =>
            Assert.equal(msg.status, 'done')
            callback()

    finalizeWorkers: () ->
        for worker in @workers
            worker.on 'message', (msg) =>
                for own clientId, latency of msg
                    @results[clientId] = latency
            worker.send({status: 'start'})
            @emit('start')

module.exports = ClientMaster
