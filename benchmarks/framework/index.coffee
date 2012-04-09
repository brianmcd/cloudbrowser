Path         = require('path')
Server       = require('./server')
SSHServer    = require('./ssh_server')
Exec         = require('child_process').exec

Client = require('./client')

for own prop of Client
    exports[prop] = Client[prop]

exports.createServer = (opts, callback) ->
    server = new Server(opts)
    if callback?
        server.once 'ready', () ->
            callback(server)
    return server

exports.createSSHServer = (opts, callback) ->
    server = new SSHServer(opts)
    if callback?
        server.once 'ready', () ->
            callback(server)
    return server

exports.gnuPlot = (script, callback) ->
    cwd = Path.dirname(module.parent.filename)
    Exec "gnuplot #{script}", {cwd : cwd}, (err, stdout) ->
        throw err if err
        callback() if callback
