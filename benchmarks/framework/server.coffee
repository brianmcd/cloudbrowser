FS             = require('fs')
Path           = require('path')
Fork           = require('child_process').fork
{EventEmitter} = require('events')

process.env.NODE_ENV = 'production'
class Server extends EventEmitter
    # args is an array of command line arguments to pass to the server.
    constructor: (opts) ->
        {app,
         nodeArgs,
         serverArgs,
         printEventsPerSec,
         printEverything} = opts

        appPrefix = 'benchmarks/framework/apps'

        if app == 'chat2'
            serverArgs = serverArgs.concat(['--knockout'])

        serverCwd = Path.resolve(__dirname, '..', '..')

        appPath = Path.resolve(serverCwd, 'benchmarks', 'framework', 'apps', app, 'app.js')
        if FS.existsSync(appPath)
            serverArgs.push(appPath)
        else
            serverArgs.push(Path.resolve(serverCwd, app))

        nodeOpts =
            cwd : serverCwd
            env : process.env
        serverPath = Path.resolve(serverCwd, 'bin', 'server')

        if nodeArgs
            serverArgs = nodeArgs.concat(serverArgs)
            # HACK HACK HACK
            # See node's fork implementation (node/lib/child_process.js).
            # This is the only way to allow us to pass startup options to node
            # itself, since these need to come before the module name.
            # This works on node 0.7.6.
            #
            # TODO: patch this in node and send a PR.
            oldUnshift = Array.prototype.unshift
            Array.prototype.unshift = (elem) ->
                # Instead of putting it at position 0, put it at the position
                # after the node/v8 options.
                if elem == serverPath
                    @splice(nodeArgs.length, 0, elem)
                else
                    oldUnshift.apply(this, arguments)

        @server = Fork(serverPath, serverArgs, nodeOpts)

        if nodeArgs
            Array.prototype.unshift = oldUnshift

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
        @server.once('exit', callback) if callback?
        @server.kill()

module.exports = Server
