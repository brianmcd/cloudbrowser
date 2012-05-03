Client = require('./client')

EMIT_INTERVAL = 20

class LockstepClientWithDelay extends Client
    constructor: (@id, @appid, @browserid, @serverAddress, @clientData) ->
        {@event, @delay} = @clientData
        @latencies = Array(EMIT_INTERVAL)
        @latencySum = 0
        @currentEventStart = null
        @numSent = 0

        @connectSocket (socket) =>
            @socket = socket
            @emit('Ready')

    sendOneEvent: () ->
        runIt = () =>
            @currentEventStart = Date.now()
            @socket.emit('processEvent', @event, ++@numSent)
        if typeof @delay == 'number'
            setTimeout(runIt, @delay)
        else
            delay = (Math.random() * 4 + 1) * 1000
            setTimeout(runIt, delay)

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
        # Jitter: add 0-15s of delay before starting.
        setTimeout(@sendOneEvent.bind(this), (Math.random() * 15)*1000)

module.exports = LockstepClientWithDelay
