Assert = require('assert')
Client = require('./client')

EVENT_BUFFER_SIZE = 1000

# TODO: rename to UpdatesPerSecondClient
class RequestsPerSecondClient extends Client
    constructor: (@id, @appid, @browserid, @serverAddress, @clientData) ->
        {@rate, @event} = @clientData
        @events = Array(EVENT_BUFFER_SIZE)
        @latencySum = 0
        @numSent = 0

        @connectSocket (socket) =>
            @socket = socket
            @emit('Ready')

    sendOneEvent: () =>
        id = @numSent++
        Assert.equal(@events[id % EVENT_BUFFER_SIZE], undefined)
        @events[id % EVENT_BUFFER_SIZE] = Date.now()
        @socket.emit('processEvent', @event, id)

    countEvent: (id) =>
        @latencySum += Date.now() - @events[id % EVENT_BUFFER_SIZE]
        @events[id % EVENT_BUFFER_SIZE] = undefined
        if id % 100 == 0
            @emit('Result', @latencySum / 100)
            @latencySum = 0

    start: () ->
        @socket.on('resumeRendering', @countEvent)
        setInterval(@sendOneEvent, 1000 / @rate)

module.exports = RequestsPerSecondClient
