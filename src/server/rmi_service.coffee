lodash  = require('lodash')
nodermi = require('nodermi')   

User = require('./user')

class RmiService
    constructor: (config,callback) ->
        {@rmiPort}=config
        host = null
        if config.domain?
            host = config.domain
        if config.host?
            host = config.host
        if config.rmiHost?
            host = rmiHost

        console.log "starting rmi service on #{host} #{@rmiPort}"
        
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
                rmiServer.registerClass('user', User)
                callback null, this
        )

    registerObject : (endPoint, object) ->
        @server.registerObject(endPoint, object)
            
    # options {host:,port:,objName}
    createStub : (options,callback) ->
        retrieveRequest = lodash.merge({},options)
        #retrieveRequest.objName = 'serverObj'
        @server.retrieveObj(retrieveRequest, callback)
        
module.exports=RmiService
    
