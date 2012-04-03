require('coffee-script')
{EventEmitter}   = require('events')
util             = require('util')
{noCacheRequire} = require('../../../src/shared/utils')
request          = require('request')

#TODO: jitter so that everyone isn't spamming each other at the same time.
#       maybe hold for 1-20 ms after pageloaded when spawning?
#       also, wait 1-3s before starting the worker output.

class Client extends EventEmitter
    constructor: (id, worker) ->
        console.log("Creating client #{id}")
        @id         = id
        @worker     = worker
        @numSent    = 0
        @latencySum = 0
        @events     = Array(Client.ARRAY_LENGTH)

        @connectSocket (socket) =>
            @socket = socket
            @start()

    @event: {
        type: 'click', target: 'node12', bubbles: true, cancelable: true,
        view: null, detail: 1, screenX: 2315, screenY: 307, clientX: 635,
        clientY: 166, ctrlKey: false, shiftKey: false, altKey: false,
        metaKey: false, button: 0 }

    @ARRAY_LENGTH: 1000

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
        eventId = ++@numSent
        if @events[eventId % Client.ARRAY_LENGTH] != undefined
            console.log('Event buffer overrun.')
            throw new Error()
        @events[eventId % Client.ARRAY_LENGTH] = Date.now()
        @socket.emit('processEvent', Client.event, eventId)

    countEvent: (eventId) ->
        eventId = Number(eventId)
        @latencySum += Date.now() - @events[eventId % Client.ARRAY_LENGTH]
        @events[eventId % Client.ARRAY_LENGTH] = undefined
        if eventId % 10 == 0
            @emit('result', @latencySum / 10)
            @latencySum = 0
        @sendOneEvent()

    start: (callback) ->
        @worker.once('start', @sendOneEvent.bind(this))
        @socket.on('resumeRendering', @countEvent.bind(this))
        @socket.once 'PageLoaded', () =>
            @emit('PageLoaded')

module.exports = Client
