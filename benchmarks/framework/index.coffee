ClientMaster = require('./client_master')
Server       = require('./server')

exports.createServer = (opts, callback) ->
    server = new Server(opts)
    server.once 'ready', () ->
        callback(server)

exports.createClients = (numClients, numClientsPerProcess, callbackInterval, callback) ->
    master = new ClientMaster(numClients) #TODO: numClientsPerProcess
    master.once 'start', () ->
        setInterval () ->
            callback(master.results)
        , callbackInterval
