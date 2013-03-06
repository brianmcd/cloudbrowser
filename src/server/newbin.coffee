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
FS          = require('fs')
Walk        = require('walkdir')

# For deplyoment CB instance
  # Each directory under applications is for one subdomain
  # Under the subdomain directory are the applications

if FS.existsSync "server_config.json"
  serverConfig = JSON.parse FS.readFileSync "server_config.json"

Opts = require('nomnom')
  .option 'deployment',
    flag    : true
    default : false
    help    : "Start the server in deployment mode"
  .parse()

if Opts.deployment
  console.log "Server is in deployment mode"
else
  applications = []
  paths = Walk.sync serverConfig.appDir, {max_depth:1}
  for path in paths
    opts = {}
    files = FS.readdirSync path
    if (appConfigIdx = files.indexOf('app_config\.json')) != -1
      appConfig = JSON.parse FS.readFileSync path + "/" +  files[appConfigIdx]
      for key,value of appConfig
        opts[key] = value
    if (deploymentConfigIdx = files.indexOf("deployment_config\.json")) != -1
      deploymentConfig = JSON.parse FS.readFileSync path + "/" + files[deploymentConfigIdx]
      for key,value of deploymentConfig
        opts[key] = value
    if not opts.entryPoint?
      opts.entryPoint = path + "/index.html"
    opts.mountPoint = "/" + path.split('/').pop()
    if opts.state
      require(path + "/" + opts.state).setApplicationState opts
    app = new Application(opts)
    applications.push app
    serverConfig.apps = applications
  
  server = new Server(serverConfig)
  server.once 'ready', ->
    console.log 'Server started in local mode'
