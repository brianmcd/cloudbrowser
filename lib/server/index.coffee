#!/usr/bin/env node
require('coffee-script')
express         = require('express')
Path            = require('path')
EventEmitter    = require('events').EventEmitter
BrowserManager  = require('./browser_manager')
FS              = require('fs')
HTTP            = require('./http')
SocketIO        = require('./socket_io')
DebugServer     = require('./debug')
{ko}            = require('../api/ko')

# TODO: server.listen(mainport, backgroundport, debugport)
class Server extends EventEmitter
    # config.app - the path to the default app this server is hosting.
    # config.shared - an object that will be shared among all Browsers created
    #                 by this server.
    # config.knockout - whether or not to enable server-side knockout
    constructor : (config = {}) ->
        @appPath = config.app
        if !@appPath
            throw new Error("Must supply path to an app.")
        @sharedState = config.shared || {}
        @localState  = config.local || () ->
        @staticDir   = config.staticDir || process.cwd()
        
        # We only allow 1 server and 1 BrowserManager per process.
        global.browsers = @browsers = new BrowserManager()
        global.server = this

        @httpServer = new HTTP
            browsers    : @browsers
            sharedState : @sharedState
            localState  : @localState
            appPath     : @appPath
        @httpServer.once('listen', @registerServer)
        @httpServer.listen(3000)

        @debug = new DebugServer
            browsers : @browsers
        @debug.once('listen', @registerServer)
        @debug.listen(3002)

        @socketIOServer = new SocketIO
            http : @httpServer.getRawServer()
            browsers : @browsers

        @internalServer = express.createServer()
        @internalServer.configure () =>
            @internalServer.use(express.static(@staticDir))
        @internalServer.listen 3001, => # TODO: port shouldn't be hardcoded.
           console.log('Internal HTTP server listening on port 3001.')
           @registerServer()

    close : () ->
        @browsers.close()
        closed = 0
        closeServer = () =>
            if ++closed == 3
                @listeningCount = 0
                @emit('close')
        @httpServer.once('close', closeServer)
        @internalServer.once('close', closeServer)
        @debug.once('close', closeServer)
        @httpServer.close()
        @internalServer.close()
        @debug.close()

    registerServer : () =>
        if !@listeningCount
            @listeningCount = 1
        else if ++@listeningCount == 3
            @emit('ready')

module.exports = Server
