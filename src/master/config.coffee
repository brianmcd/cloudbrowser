utils = require '../shared/utils'
lodash = require 'lodash'

class MasterConfig
    constructor: (path, callback) ->
        # enable embeded reverse proxy server, we may also need a option to start a standalone proxy
        @enableProxy = false
        # port to serve queries from proxy server 
        @proxyPort = 3030
        # port for rmi service
        @rmiPort = 3040
        
        utils.readJsonFromFileAsync(path, (e, obj) =>
            if e
                callback e
            else
                lodash.merge(this, obj)

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




exports.MasterConfig = MasterConfig