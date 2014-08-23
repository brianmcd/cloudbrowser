FS             = require('fs')
Path           = require('path')
Fork           = require('child_process').fork
{EventEmitter} = require('events')
timers         = require('timers')

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

        if app == 'chat2' || app == 'doodle'
            serverArgs = serverArgs.concat(['--knockout'])

        rootDir = Path.resolve(__dirname, '..', '..')
        # default application
        appPath = Path.resolve(rootDir, 'benchmarks', 'framework', 'apps', app, 'index.html')
        if FS.existsSync(appPath)
            serverArgs.push(appPath)
        else
            serverArgs.push(Path.resolve(rootDir, app))

        nodeOpts =
            cwd : rootDir
            env : process.env
        masterScriptPath = Path.resolve(rootDir, 'src/master/master_main.coffee' )
        serverPath = Path.resolve(rootDir, 'src/server/newbin.coffee')

        timeOutObj = timers.setTimeout(()=>
            @emit('initError', 'timeOut')
        , 5000)

        eventQueue = new EventEmitter()
        dependencyCount = 1 + opts.workerCount
        readyCount = 0
        eventQueue.on('ready', ()=>
            readyCount++
            if readyCount is dependencyCount
                @emit('ready')
                timers.clearTimeout timeOutObj
        )

        masterProcess = Fork(masterScriptPath, serverArgs)
        masterProcess.on('message', (msg)=>
            switch msg.type
                when 'ready'
                    console.log "master is ready"
                    eventQueue.emit('ready')
                when 'initError'
                    @emit('initError')
                else
                    console.log "other msg from master"
        )

        console.log "start #{opts.workerCount} workers"

        workerProcesses = []
        for i in [0...opts.workerCount] by 1
            workerConfig = Path.resolve(rootDir, "config/worker#{i+1}")
            workerArgs = [process.argv[0], process.argv[1], "--configPath=#{workerConfig}"]
            workerProcesses[i] = Fork(serverPath, workerArgs)
            workerProcesses[i].on('message',(msg)->
                switch msg.type
                    when 'ready'
                        console.log "worker is ready"
                        eventQueue.emit('ready')
                    when 'initError'
                        @emit('initError')
                    else
                        console.log "other msg from master"
            )


    send: (msg) ->
        @server.send(msg)

    stop: (callback) ->
        @server.once('exit', callback) if callback?
        @server.kill()

module.exports = Server
