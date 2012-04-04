Path           = require('path')
Fork           = require('child_process').fork
{EventEmitter} = require('events')

process.env.NODE_ENV = 'production'
class Server extends EventEmitter
    # args is an array of command line arguments to pass to the server.
    constructor: (opts) ->
        {args, printEventsPerSec, printEverything} = opts

        nodeOpts =
            cwd : Path.resolve(__dirname, '..', '..')
            env : process.env
        serverPath = Path.resolve(__dirname, '..', '..', 'bin', 'server')

        @server = Fork(serverPath, args, nodeOpts)
        @server.on 'message', (msg) =>
            switch msg.type
                when 'log'
                    data = msg.data
                    if printEverything
                        process.stdout.write(data)
                    else if printEventsPerSec && /^Processing/.test(data)
                        process.stdout.write(data)
                    if /^All\sservices\srunning/.test(data)
                        @emit('ready')
                else
                    @emit('message', msg)

        process.on('exit', () => @server?.kill())

    send: (msg) ->
        @server.send(msg)

    stop: (callback) ->
        @server.once('exit', callback)
        @server.kill()

module.exports = Server
