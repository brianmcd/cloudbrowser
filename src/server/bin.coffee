# If we were called with child_process.fork, we want to set up a lightweight
# RPC channel that can be used to collect statistics and invoke gc.
if process.send? then do () ->
    # We need to make console.log send RPC messages instead of writing to
    # stdout since child_process.fork merges the child's stdout with the
    # parent's, and there's currently no way to disable that.
    log = () ->
        args = Array.prototype.slice.call(arguments)
        process.send
            type: 'log'
            data: args.join(' ')
    process.stdout.write = log
    process.stderr.write = log
    process.on 'message', (msg) ->
        switch msg.type
            when 'gc'
                gc() for i in [1..7]
            when 'memory'
                process.send
                    type: 'memory'
                    data: process.memoryUsage()
            when 'closeBrowser'
                browser = global.weakRefList[msg.id]
                throw new Error if !browser
                browser.close()
            when 'ping'
                process.send
                    type: 'pong'
    process.env.WAS_FORKED = true

Path        = require('path')
Util        = require('util')
Server      = require('./index')
{ko}        = require('../api/ko')
Application = require('./application')
Router      = require('./router')

opts = require('nomnom')
    .option 'debug',
        flag    : true
        default : false
        help    : "Enable debug mode."
    .option 'noLogs',
        full    : 'disable-logging'
        flag    : true
        default : false
        help    : "Disable all logging to files."
    .option 'debugServer',
        full    : 'debug-server'
        flag    : true
        default : false
        help    : "Enable the debug server."
    .option 'compression',
        default : true
        help    : "Enable protocol compression."
    .option 'compressJS',
        full : 'compress-js'
        default : false
        help : "Pass socket.io and client engine through uglify and gzip."
    .option 'knockout',
        default : false
        flag    : true
        help    : "Enable server-side knockout.js bindings."
    .option 'strict',
        default : false
        flag    : true
        help    : "Enable strict mode - uncaught exceptions exit the program."
    .option 'resourceProxy',
        full    : 'resource-proxy'
        default : true
        help    : "Enable ResourceProxy."
    .option 'monitorTraffic',
        full    : 'monitor-traffic'
        default : false
        help    : "Monitor/log traffic to/from socket.io clients."
    .option 'traceProtocol',
        full    : 'trace-protocol'
        default : false
        help    : "Log protocol messages to browserid-rpc.log."
    .option 'evalMode',
        full    : 'eval-mode'
        default : false
        help    : "Enable evaluation mode for performance measuring."
    .option 'multiProcess',
        full    : 'multi-process'
        default : false
        help    : "Run each browser in its own process (can't be used with shared global state)."
    .option 'useRouter',
        full    : 'router'
        default : false
        help    : "Use a front-end router process with each app server in its own process."
    .option 'port',
        default : 3000
        help    : "Starting port to use."
    .option 'traceMem',
        full    : 'trace-mem'
        default : false
        flag    : true
        help    : "Trace memory usage."
    .option 'adminInterface',
        full    : 'admin-interface'
        default : false
        help    : "Enable the admin interface."
    .option 'simulateLatency',
        full    : 'simulate-latency'
        default : false
        help    : "Simulate latency for clients in ms (if not given assign uniform randomly in 20-120 ms range."
    .option 'app',
        position : 0
        required : true
        help     : "The configuration function for the default application."
    .parse()

if opts.debug
    console.log("Config:")
    console.log(Util.inspect(opts))

if !opts.strict
    process.on 'uncaughtException', (err) ->
        console.log("Uncaught Exception:")
        console.log(err)
        console.log(err.stack)

defaultApp = null
# We support passing a URL instead of an application config file for quick
# testing.
if /^http/.test(opts.app) || /\.html$/.test(opts.app)
    appOpts =
        entryPoint : opts.app
        mountPoint : '/'
    appOpts.browserStrategy = 'multiprocess' if opts.multiProcess
    defaultApp = new Application(appOpts)
else
    appConfigPath = Path.resolve(process.cwd(), opts.app)
    appOpts = require(appConfigPath).app
    defaultApp = new Application(appOpts)

s = null
if opts.useRouter
    # TODO: debugServer needs to become part of app spec.
    s = new Router(opts.port)
    s.mount(defaultApp)
else
    opts.defaultApp = defaultApp
    s = new Server(opts)
    s.once 'ready', () ->
        console.log('All services running, ready for clients.')
