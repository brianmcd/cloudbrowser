utils = require '../shared/utils'
lodash = require 'lodash'

class MasterConfig
    constructor: (path, callback) ->
        # enable embeded reverse proxy server, we may also need a option to start a standalone proxy
        @enableProxy = false
        # port to serve queries from proxy server 
        @proxyPort = 5000
        # port to listen to requests from workers
        @workerPort = 6000
        @workers = []
        utils.readJsonFromFileAsync(path, (e, obj) =>
            if e
                callback e
            else
                lodash.merge(this, obj)
                if not @workers?
                    return callback(new Error('Should config at least one worker'))

                # copy default values
                oldWorkers = @workers
                @workers = []
                for w in @workers
                    worker = new Worker()
                    lodash.merge(worker,w)
                    @workers.push(worker)

                if @enableProxy
                    proxyConfig = new ProxyConfig()
                    if @proxyConfig?
                        lodash(proxyConfig, @proxyConfig)
                    @proxyConfig = proxyConfig

                callback null, this           
            )

class ProxyConfig
    constructor: () ->
        @host = 'localhost'
        @httpPort = 3000

class Worker
    constructor: () ->
        @host = 'localhost'
        @httpPort = 3000
        @adminPort = 4000
    



exports.MasterConfig = MasterConfig