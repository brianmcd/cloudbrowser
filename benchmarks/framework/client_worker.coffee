{EventEmitter} = require('events')
Assert         = require('assert')
Client         = require('./client')

class ClientWorker extends EventEmitter
    constructor: (@startId, @numClients, @sendMessages) ->
        @setMaxListeners(0)
        @endId      = @startId + @numClients
        @currentId  = @startId

        console.log("Worker creating clients #{@startId} - #{@endId - 1}")

        @results = {}

        # Don't start the clients until the Master tells us to.
        process.once 'message', (msg) =>
            Assert.equal(msg.status, 'start')
            @emit('start')

    start: () -> @startNextClient()

    startNextClient: () ->
        if @currentId == @endId
            return process.send({status: 'done'})

        client = new Client(@currentId++, @sendMessages, this)

        client.on 'result', (latency) =>
            @results[client.id] = latency

        client.once 'PageLoaded', () =>
            process.nextTick () =>
                @startNextClient()

module.exports = ClientWorker
