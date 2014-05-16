class HttpProxy
    constructor: (dependencies, callback) ->
        @config = dependencies.config.proxyConfig
        @workerManager = dependencies.workerManager
        httpProxy = require('http-proxy')
        @proxy = httpProxy.createProxyServer({})
        server = require('http').createServer((req, res) =>
            @proxyRequest req, res
        )
        server.on('upgrade', (req, socket, head) =>
            @proxyWebSocketRequest req, socket, head
        )        
        console.log "starting proxy server listening on #{@config.httpPort}"
        server.listen(@config.httpPort, ()=>
            callback null, this
        )
    
    proxyWebSocketRequest : (req, socket, head) ->
        console.log "proxy ws request #{req.url}"
        {worker} = @workerManager.getWorker(req)
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
            console.log "Redirect #{req.url} to #{redirect}"
            req.url = redirect
        if not worker?
            console.log 'cannot find a worker'
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