require('coffee-script')
{EventEmitter}   = require('events')
util             = require('util')
{noCacheRequire} = require('../../src/shared/utils')
request          = require('request')

class Client extends EventEmitter
    constructor: (id, worker) ->
        console.log("Creating client #{id}")
        @id         = id
        @worker     = worker
        @latencySum = 0
        @currentEventStart = null
        @numSent = 0

        @connectSocket (socket) =>
            @socket = socket
            @start()

    @event: {
        type: 'click', target: 'node12', bubbles: true, cancelable: true,
        view: null, detail: 1, screenX: 2315, screenY: 307, clientX: 635,
        clientY: 166, ctrlKey: false, shiftKey: false, altKey: false,
        metaKey: false, button: 0 }

    connectSocket: (callback) ->
        opts = {url: 'http://localhost:3000', jar: false}
        request opts, (err, response, body) ->
            throw err if err
            browserid = /window.__envSessionID\ =\ '(.*)'/.exec(body)[1]
            appid = /window.__appID\ =\ '(.*)'/.exec(body)[1]
            socketio = noCacheRequire('socket.io-client')
            socket = socketio.connect('http://localhost:3000')
            socket.emit('auth', appid, browserid)
            callback(socket)

    sendOneEvent: () ->
        @currentEventStart = Date.now()
        @socket.emit('processEvent', Client.event, @numSent++)

    countEvent: (eventId) ->
        @latencySum += Date.now() - @currentEventStart
        @currentEventStart = null
        if eventId % 10 == 0 # TODO: this number needs to be configurable.
            @emit('result', @latencySum / 10)
            @latencySum = 0
        @sendOneEvent()

    start: () ->
        @worker.once('start', @sendOneEvent.bind(this))
        @socket.on('resumeRendering', @countEvent.bind(this))
        @socket.once 'PageLoaded', () =>
            @emit('PageLoaded')

module.exports = Client
