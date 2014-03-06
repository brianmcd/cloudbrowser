utils = require '../shared/utils'
lodash = require 'lodash'

class MasterConfig
    constructor: (path, callback) ->
        # enable embeded reverse proxy server, we may also need a option to start a standalone proxy
        @enableProxy = false
        # port to serve queries from proxy server 
        @proxyPort = 3030
        # port to listen to requests from workers
        @workerPort = 3040
        
        utils.readJsonFromFileAsync(path, (e, obj) =>
            if e
                callback e
            else
                lodash.merge(this, obj)
                if not @workers?
                    return callback(new Error('Should config at least one worker'))
                # new a instance from class Worker 
                # for each worker obj from config file.
                # merge these two to get methods and default values in Class worker
                oldWorkers = @workers
                @workers = []

                for w in oldWorkers
                    worker = new Worker()
                    lodash.merge(worker,w)
                    @workers.push(worker)

                if @enableProxy
                    # copy default values --> see the comments above
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
        @id = '0'
        @host = 'localhost'
        @httpPort = 4000
        @adminPort = 5000
    



exports.MasterConfig = MasterConfig