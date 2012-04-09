{EventEmitter} = require('events')
Spawn = require('child_process').spawn
Exec = require('child_process').exec

class SSHServer extends EventEmitter
    constructor: (opts) ->
        {host,
         cmd,
         printEventsPerSec,
         printEverything} = opts

        @sshOpts = host.split(' ')

        @server = Spawn('ssh', @sshOpts.concat(cmd))
        @server.stderr.setEncoding('utf8')
        @server.stderr.on 'data', (data) ->
            console.log(data)

        @server.stdout.setEncoding('utf8')
        buffer = ''
        ready = false
        @server.stdout.on 'data', (data) =>
            if !ready
                buffer += data
            if printEverything
                process.stdout.write(data)
            else if printEventsPerSec && /^Processing/.test(data)
                process.stdout.write(data)
            if /All\sservices\srunning/.test(buffer)
                ready = true
                buffer = ''
                @emit('ready')

        process.on 'exit', () =>
            if @server
                @server.kill()
                killCmd = "ssh #{@sshOpts.concat(["killall node"]).join(' ')}"
                Exec(killCmd)

    stop: (callback) ->
        timesCalled = 0
        checker = () -> callback() if callback? && ++timesCalled == 2
        @server.once('exit', checker)
        @server.kill()
        @server = null
        killCmd = "ssh #{@sshOpts.concat(["killall node"]).join(' ')}"
        console.log("killcmd: #{killCmd}")
        Exec(killCmd, checker)

module.exports = SSHServer
