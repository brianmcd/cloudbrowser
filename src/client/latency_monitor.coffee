class LatencyMonitor
    constructor : (client) ->
        @client = client
        @nextEventID = 0
        @pendingEvents = {}
        @finishedEvents = {}

    start : (type) ->
        id = ++@nextEventID
        @pendingEvents[id] =
            start   : Date.now()
            stop    : -1
            type    : type
            elapsed : -1
        return id

    stop : (id) ->
        stop = Date.now()
        entry = @pendingEvents[id]
        return if !entry?
        delete @pendingEvents[id]
        entry.stop = stop
        entry.elapsed = stop - entry.start
        return @finishedEvents[id] = entry

    cancel : (id) ->
        delete @pendingEvents[id]

    sync : () ->
        @client.socket.emit('latencyInfo', @finishedEvents)

module.exports = LatencyMonitor
