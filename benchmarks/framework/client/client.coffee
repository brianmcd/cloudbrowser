{EventEmitter}   = require('events')
{noCacheRequire} = require('../../../src/shared/utils')
request          = require('request')

class Client extends EventEmitter
    constructor: (@id, @appid, @browserid, @clientData) ->
        @connectSocket (socket) =>
            @socket = socket

    connectSocket: (callback) ->
        socketio = noCacheRequire('socket.io-client')
        if !@appid && !@browserid
            opts = {url: 'http://localhost:3000', jar: false}
            request opts, (err, response, body) =>
                throw err if err
                @browserid = /window.__envSessionID\ =\ '(.*)'/.exec(body)[1]
                @appid = /window.__appID\ =\ '(.*)'/.exec(body)[1]
                socket = socketio.connect('http://localhost:3000')
                socket.emit('auth', @appid, @browserid)
                socket.once 'PageLoaded', () =>
                    @emit('Ready')
                callback(socket)
        else
            socket = socketio.connect('http://localhost:3000')
            socket.emit('auth', @appid, @browserid)
            socket.once 'PageLoaded', () =>
                @emit('Ready')
            callback(socket)

    start: () ->

module.exports = Client
