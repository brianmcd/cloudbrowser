Server              = require('./index')
FS                  = require('fs')

if FS.existsSync "server_config.json"
    serverConfig = JSON.parse FS.readFileSync "server_config.json"
else
    throw new Error "Missing required configuration file - server_config.json. Please run CloudBrowser from the project root directory."

Opts = require('nomnom')
    .option 'deployment',
        flag    : true
        default : false
        help    : "Start the server in deployment mode"
    .parse()

if Opts.deployment
    console.log "Server started in deployment mode"
else
    paths = []
    #List of all the unmatched positional args (the path names)
    for item in Opts._
        paths.push item
    server = new Server(serverConfig, paths)
    server.once 'ready', ->
        console.log 'Server started in local mode'
