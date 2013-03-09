Server              = require('./index')
FS                  = require('fs')

if FS.existsSync "server_config.json"
    serverConfig = JSON.parse FS.readFileSync "server_config.json"

Opts = require('nomnom')
    .option 'deployment',
        flag    : true
        default : false
        help    : "Start the server in deployment mode"
    .parse()

if Opts.deployment
    console.log "Server started in deployment mode"
else
    server = new Server(serverConfig)
    server.once 'ready', ->
        console.log 'Server started in local mode'
