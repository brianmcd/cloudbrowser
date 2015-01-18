debug = require('debug')
lodash = require('lodash')

{HttpProxyWorker} = require('./http_proxy_worker')

logger = debug('cloudbrowser:master:proxy')
infoLogger = debug('cloudbrowser:master:proxyInfo')


class HttpProxy
    constructor: (options) ->
        {@config, callback, @workerManager } = options
        @worker = new HttpProxyWorker({
            requestHandler : @proxyRequest.bind(this)
            wsReqestHandler : @proxyWebSocketRequest.bind(this)
            logger : logger
            infoLogger : infoLogger
        });
        socketServer = require('net').createServer()
        socketServer.listen(@config.httpPort, 2048, ()=>
            infoLogger "starting proxy server listening on #{@config.httpPort}"
            @worker.listen(socketServer)
            if @config.workers? and @config.workers > 0
                @createWorkers(@config.workers, socketServer)
            callback(null, this)
        )

    # create proxy processes
    createWorkers: (count, socketServer)->
        @childProcesses = []
        for i in [0...count] by 1
            childProcess = require('child_process').fork('src/master/http_proxy_worker.js')
            @childProcesses.push(childProcess)
            childConfig = lodash.clone(@config)
            childConfig.id = i
            childProcess.send({
                type : 'config'
                config : childConfig
            }, socketServer)
            do(childProcess)=>
                childProcess.on('message', (msg)=>
                    if msg? and msg.type is 'getWorkerReq'
                        @childMessageHandler(childProcess, msg)
                )

    childMessageHandler : (childProcess, msg)->
        {req, id} = msg
        {worker, redirect} = @workerManager.getWorker(req)
        childProcess.send({
            type : 'getWorkerRes'
            id : id
            worker : worker
            redirect : redirect
        })

    proxyWebSocketRequest : (req, socket, head) ->
        {worker} = @workerManager.getWorker(req)
        @worker.proxyWebSocketRequest(req, socket, head,worker)
        

    proxyRequest : (req, res) ->
        {worker, redirect} = @workerManager.getWorker(req)
        ret = @worker.proxyRequest(req, res, worker, redirect)
        if ret
            @workerManager.registerRequest(worker.id)

module.exports = (dependencies,callback) ->
    config = dependencies.config.proxyConfig
    {workerManager} = dependencies
    return new HttpProxy({
        config : config
        workerManager : workerManager
        callback : callback
    })

###
httpProxy = require('http-proxy')
proxy = httpProxy.createProxyServer({})
server = require('http').createServer((req, res) =>
    req.url = 'http://www.google.com/imghp'
    proxy.web(req, res, { target: {host:'www.google.com',port:80} })
)
server.listen(3000)
###