var http = require('http');

http.globalAgent.maxSockets = 65535

var httpProxy = require('http-proxy');
var debug = require('debug');
var lodash = require('lodash');


function HttpProxyWorker(options){
    this.proxy = httpProxy.createProxyServer({});
    this.server = http.createServer(options.requestHandler);
    this.server.on('upgrade', options.wsReqestHandler);
    
    this.logger = options.logger;
    if (!this.logger) {
        this.logger = debug("cloudbrowser:master:proxy");
    }
    this.infoLogger = options.infoLogger;
    if (!this.infoLogger) {
        this.infoLogger = this.logger;
    }
    var infoLogger = this.infoLogger;
    this.proxy.on('error', function proxyError(err, req, res, target){
        var errorMsg = null;
        if (target && target.host) {
            errorMsg = "Proxy error "+ err.message + " @ " + target.host + ":" + target.port +" " + req.url;
        }else{
            errorMsg = "Proxy error "+ err.message + " @null " + req.url;
        }
        infoLogger("Proxy error #{err.message} #{target?.host}:#{target?.port} #{req.url}");
        infoLogger(err.stack);
        res.writeHead(500, "Proxy Error.");
        res.end();
    });
}

lodash.assign(HttpProxyWorker.prototype, {
    listen : function(socket, callback){
        if(!callback){
            callback = lodash.noop;
        }
        var self = this;
        this.server.listen(socket, 2048, function(){
            callback(null, self);
        });
    },
    // return if it is successfully proxied
    proxyRequest : function(req, res, worker, redirect){
        if(!worker){
            this.infoLogger('cannot find a worker');
            res.writeHead(404);
            res.end("The url is no longer valid.");
            return false
        }
        if(redirect!=null){
            this.logger("Redirect "+req.url +" to "+redirect);
            req.url = redirect;
            return false
        }
        this.logger("proxy reqeust "+ req.url+" to "+worker.id);
        this.proxy.web(req, res, {
            target:
                {
                    host : worker.host,
                    port : worker.httpPort
                }
         })
        return true
    },
    proxyWebSocketRequest : function(req, socket, head, worker){
        if(!worker){
            // TODO integrate with socket.io to send useful
            // error info back to client
            return socket.close();
        }
        this.logger("proxy ws request "+ req.url +" to "+ worker.id);
        this.proxy.ws(req, socket, head, {
            target:
                {
                    host : worker.host,
                    port : worker.httpPort
                }
        })
    }
});

if (require.main === module){
    var logger = debug('cloudbrowser:master:proxy');
    var infoLogger = debug('cloudbrowser:master:proxyInfo');
    var pid = process.pid;
    var workerId = -1;
    infoLogger("Proxy worker "+pid+" started.");

    var msgId = 0;
    var requestQueue = [];

    function getWorkerResHandler(msg){
        var id = msg.id;
        var index = -1;
        for (var i = requestQueue.length - 1; i >= 0; i--) {
            if (requestQueue[i].id === id) {
                index = i;
                break;
            }
        }
        if (index>=0) {
            var queued = requestQueue[i];
            requestQueue.splice(index,1);
            var worker = msg.worker;
            if (queued.socket) {
                httpProxyWorker.proxyWebSocketRequest(queued.req, queued.socket, queued.head, worker);
            }else{
                var redirect = msg.redirect;
                httpProxyWorker.proxyRequest(queued.req, queued.res, worker, redirect);
            }
        }else{
            infoLogger("cannot find matched request for "+JSON.stringify(msg));
        }
    }

    function createGetWorkerReq(req){
        var id = msgId++;
        var reqObj = {
            url : req.url
        };
        if (req.headers && req.headers.referer) {
            reqObj.headers = {
                referer : req.headers.referer
            };
        }
        return {
            type : 'getWorkerReq',
            id: id,
            req : reqObj
        };
    }

    function proxyRequest(req, res){
        logger("ProxyWorker #"+workerId+" get a request "+req.url);
        var getWorkerReq = createGetWorkerReq(req);
        process.send(getWorkerReq);
        requestQueue.push({
            id : getWorkerReq.id,
            req : req,
            res : res
        });
    }

    function proxyWebSocketRequest(req, socket, head){
        logger("ProxyWorker #"+workerId+" get a request "+req.url);
        var getWorkerReq = createGetWorkerReq(req);
        // indicate this is from websocket request
        getWorkerReq.websocket = true;
        process.send(getWorkerReq);
        requestQueue.push({
            id : getWorkerReq.id,
            req : req,
            socket : socket,
            head : head
        });

    }

    var httpProxyWorker = new HttpProxyWorker({
        requestHandler : proxyRequest,
        wsReqestHandler : proxyWebSocketRequest,
        logger : logger,
        infoLogger : infoLogger
    });

    process.on("message", function(msg, sendHandle){
        if (msg.type === 'config') {
            var config = msg.config;
            logger("proxy worker "+pid + "->" + config.id+" get config.");
            workerId = config.id;
            httpProxyWorker.listen(sendHandle);
            return;
        }
        if (msg.type === 'getWorkerRes') {
            getWorkerResHandler(msg);
            return;
        }
        infoLogger("unknown type of message "+JSON.stringify(msg));
    });
}

exports.HttpProxyWorker = HttpProxyWorker