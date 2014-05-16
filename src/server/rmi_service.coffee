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
                    console.log "Starting rmi service failed"
                    if err.code is 'EADDRINUSE'
                        console.log "Maybe the rmiport #{@rmiPort} is occupied by other apps, please change your configration"
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
    
