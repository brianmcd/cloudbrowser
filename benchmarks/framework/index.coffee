Path         = require('path')
ClientMaster = require('./client_master')
Server       = require('./server')

exports.client = require('./client')

exports.createServer = (opts, callback) ->
    server = new Server(opts)
    if callback?
        server.once 'ready', () ->
            callback(server)
    return server

exports.createClients = (numClients, numClientsPerProcess, callbackInterval, callback) ->
    master = new ClientMaster(numClients) #TODO: numClientsPerProcess
    master.once 'start', () ->
        if callback? && callbackInterval?
            setInterval () ->
                callback(master.results)
            , callbackInterval
    return master

exports.gnuPlot = (script) ->
    cwd = path.dirname(module.parent.filename)
    Exec "gnuplot #{script}", {cwd : cwd}, (err, stdout) ->
        throw err if err
