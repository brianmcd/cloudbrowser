{EventEmitter}   = require('events')
{noCacheRequire} = require('../../../src/shared/utils')
request          = require('request')

class Client extends EventEmitter
    constructor: (@id, @appid, @appInstanceId, @browserid, @serverAddress, @clientData) ->
        @connectSocket (socket) =>
            @socket = socket

    connectSocket: (callback) ->
        socketio = noCacheRequire('socket.io-client')
        if !@appid && !@browserid
            opts = {url: @serverAddress, jar: false}
            request opts, (err, response, body) =>
                throw err if err
                @browserid = response.headers['x-cb-browserid']
                @appid = response.headers['x-cb-appid']
                @appInstanceId = response.headers['x-cb-appinstanceid']
                if not @appid? or not @browserid?
                    throw new Error("Something is wrong, no browserid detected.")
                

                socket = socketio.connect(@serverAddress)
                socket.emit('auth', @appid, @appInstanceId, @browserid)
                socket.once 'PageLoaded', () =>
                    @emit('Ready')
                callback(socket)
        else
            socket = socketio.connect(@serverAddress)
            socket.emit('auth', @appid, @appInstanceId, @browserid)
            socket.once 'PageLoaded', () =>
                @emit('Ready')
            callback(socket)

    start: () ->

module.exports = Client
