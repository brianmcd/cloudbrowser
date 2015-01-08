debug = require('debug')

logger = debug('cloudbrowser:master:proxy')

infoLogger = debug('cloudbrowser:master:proxyInfo')

class HttpProxy
    constructor: (dependencies, callback) ->
        @config = dependencies.config.proxyConfig
        @workerManager = dependencies.workerManager
        httpProxy = require('http-proxy')
        @proxy = httpProxy.createProxyServer({})
        http = require('http')
        http.globalAgent.maxSockets = 65535
        server = http.createServer((req, res) =>
            @proxyRequest req, res
        )
        server.on('upgrade', (req, socket, head) =>
            @proxyWebSocketRequest req, socket, head
        )
        @proxy.on('error', (err, req, res, target)=>
            infoLogger "Proxy error #{err.message} #{target?.host}:#{target?.port} #{req.url}"
            infoLogger err.stack
            res.writeHead(500, "Proxy Error.")
            res.end()
        )
        infoLogger "starting proxy server listening on #{@config.httpPort}"
        server.listen(@config.httpPort, 2048, (err)=>
            callback err, this
        )

    proxyWebSocketRequest : (req, socket, head) ->
        {worker} = @workerManager.getWorker(req)
        if not worker?
            # TODO integrate with socket.io to send useful
            # error info back to client
            return socket.close()
        
        logger "proxy ws request #{req.url} to #{worker.id}"
        @proxy.ws(req, socket, head, {
            target:
                {
                    host : worker.host,
                    port : worker.httpPort
                }
        })

    proxyRequest : (req, res) ->
        {worker, redirect} = @workerManager.getWorker(req)
        if redirect?
            logger "Redirect #{req.url} to #{redirect}"
            req.url = redirect
        if not worker?
            logger 'cannot find a worker'
            res.writeHead(404)
            return res.end("The url is no longer valid.")
        logger("proxy reqeust #{req.url} to #{worker.id}")
        @workerManager.registerRequest(worker.id)
        @proxy.web(req, res, {
            target:
                {
                    host : worker.host,
                    port : worker.httpPort
                }
         })

module.exports = (dependencies,callback) ->
    new HttpProxy(dependencies,callback)

###
httpProxy = require('http-proxy')
proxy = httpProxy.createProxyServer({})
server = require('http').createServer((req, res) =>
    req.url = 'http://www.google.com/imghp'
    proxy.web(req, res, { target: {host:'www.google.com',port:80} })
)
server.listen(3000)
###