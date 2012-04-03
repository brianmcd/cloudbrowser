Path           = require('path')
Spawn          = require('child_process').spawn
{EventEmitter} = require('events')

# TODO: knobs for measuring stuff in the server.
#       - memory usage?
#       - bandwidth?
# TODO: we could have bin/server detect if it was started with fork() (if process.send), and if so, send statistics every 5s

process.env.NODE_ENV = 'production'
class Server extends EventEmitter
    # args is an array of command line arguments to pass to the server.
    constructor: (opts) ->
        {args, printEventsPerSec, printEverything} = opts

        nodeOpts =
            cwd : Path.resolve(__dirname, '..', '..')
            env : process.env
        nodeArgs = [Path.resolve(__dirname, '..', '..', 'bin', 'server')].concat(args)

        @server = Spawn('node', nodeArgs, nodeOpts)
        @server.stdout.setEncoding('utf8')
        @server.stdout.on 'data', (data) =>
            if printEverything
                process.stdout.write(data)
            else if printEventsPerSec && /^Processing/.test(data)
                process.stdout.write(data)
            if /^All\sservices\srunning/.test(data)
                @emit('ready')

        process.on('exit', () => @server.kill())

module.exports = Server
