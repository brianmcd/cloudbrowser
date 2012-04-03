{EventEmitter} = require('events')
Assert         = require('assert')
Client         = require('./client')

class Worker extends EventEmitter
    constructor: () ->
        @setMaxListeners(0)
        @startId    = parseInt(process.argv[2], 10)
        @numClients = parseInt(process.argv[3], 10)
        @endId      = @startId + @numClients
        @currentId  = @startId

        console.log("Worker creating clients #{@startId} - #{@endId - 1}")

        @results = {}

        process.once 'message', (msg) =>
            Assert.equal(msg.status, 'start')
            @emit('start')


    start: () ->
        @startNextClient()

    startNextClient: () ->
        if @currentId == @endId
            return process.send({status: 'done'})

        client = new Client(@currentId++, this)

        client.on 'result', (latency) =>
            @results[client.id] = latency

        client.once 'PageLoaded', () =>
            process.nextTick () =>
                @startNextClient()

module.exports = Worker
