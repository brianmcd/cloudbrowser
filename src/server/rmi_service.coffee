lodash  = require('lodash')
nodermi = require('nodermi')   

class RmiService
    constructor: (config,callback) ->
        {@rmiPort}=config
        console.log "starting rmi service on #{@rmiPort}"
        host = 'localhost'
        if config.domain?
            host = config.domain
        if config.host?
            host = config.host
        if config.rmiHost?
            host = rmiHost
        
        nodermi.createRmiService({
            host: host
            port: @rmiPort
            }, (err, rmiServer)=>
                if err?
                    return callback err
                @server = rmiServer
                callback null, this
        )

    createSkeleton : (endPoint, object) ->
        @server.createSkeleton(endPoint, object)
            
    # options {host:,port:,objName}
    createStub : (options,callback) ->
        retriveRequest = lodash.merge({},options)
        #retriveRequest.objName = 'serverObj'
        @server.retriveObj(retriveRequest, callback)
        
module.exports=RmiService
    
