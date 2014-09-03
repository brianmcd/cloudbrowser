Client = require('./client')

EMIT_INTERVAL = 100

class LockstepClient extends Client
    constructor: (@id, @appid, @appInstanceId, @browserid, @serverAddress, @clientData) ->
        {@event} = @clientData
        @latencies = Array(EMIT_INTERVAL)
        @latencySum = 0
        @currentEventStart = null
        @numSent = 0

        @connectSocket (socket) =>
            @socket = socket
            @emit('Ready')

    sendOneEvent: () ->
        @currentEventStart = Date.now()
        @socket.emit('processEvent', @event, ++@numSent)

    countEvent: (eventId) ->
        latency = Date.now() - @currentEventStart
        @latencies[eventId % EMIT_INTERVAL] = latency
        @latencySum += latency
        @currentEventStart = null
        if eventId % EMIT_INTERVAL == 0
            @emitResults()
            @latencySum = 0
        @sendOneEvent()

    emitResults: () ->
        # Compute average
        avgLatency = @latencySum / EMIT_INTERVAL
        # Compute variance
        sum = 0
        for latency in @latencies
            diff = latency - avgLatency
            diff *= diff
            sum += diff
        variance = sum / EMIT_INTERVAL
        @emit 'Result',
            latency: avgLatency
            variance: variance

    start: () ->
        @socket.on('resumeRendering', @countEvent.bind(this))
        @sendOneEvent()

module.exports = LockstepClient
