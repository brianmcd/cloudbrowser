Client = require('./client')

class LockstepClient extends Client
    constructor: (@id, @appid, @browserid, @serverAddress, @clientData) ->
        #console.log("Creating client #{@id}")
        {@event} = @clientData
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
        @latencySum += Date.now() - @currentEventStart
        @currentEventStart = null
        if eventId % 100 == 0 # TODO: this number needs to be configurable.
            @emit('Result', @latencySum / 100)
            @latencySum = 0
        @sendOneEvent()

    start: () ->
        @socket.on('resumeRendering', @countEvent.bind(this))
        @sendOneEvent()

module.exports = LockstepClient
