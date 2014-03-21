lodash = require('lodash')
dnode = require('dnode')
class StubObject
    # options: host, port
    constructor: (@options, callback) ->
        @init(callback)
    init:(callback) ->
        @close()
        @client=dnode({})
        @client.on('error',(error)=>
            console.log 'error in sub'
            console.log error.stack if error?
        )
        @client.on('fail',(error)=>
            console.log 'fail on the other side'
            console.log error.stack if error?            
        )
        @client.connect(@options.host, @options.port, (remote)=>
            @obj=remote
            if callback?
                callback null, this
        )

    close : () ->
        if @client?
            @client.removeAllListeners()
            try
                @client.end()
            catch e
                # ignore
                console.log e
            @client=null
            @obj=null
        
    


class RmiService
    constructor: (config) ->
        @serverObj = {}
        @rmiPort=config.rmiPort

    createSkeleton : (endPoint, object, attributes) ->
        paths = endPoint.split('.')
        objName = paths[paths.length-1]
        paths = paths[0...-1]

        holder = @serverObj
        for path, i in paths
            if not @serverObj[path]?
                @serverObj[path] = {}
            holder=@serverObj[path]

        if attributes?
            skeleton = {}
            holder[objName] = skeleton
            if lodash.isArray(attributes)
                #should be array of strings
                for attName in attributes
                    @_setSkeletonAttribute(skeleton, attName, object)
            else if lodash.isObject(attributes)
                for attName, attObj of object
                    @_setSkeletonAttribute(skeleton, attName, object)
            else 
                throw new Error('should not happen')     
        else
            holder[objName]=object

        console.log "createSkeleton in #{endPoint}"
            
    _setSkeletonAttribute : (skeleton, attName, object) ->
        attObj = object[attName]
        if lodash.isFunction(attObj)
            skeleton[attName] = lodash.bind(attObj, object)
            console.log "create Skeleton function #{attName}"
        else
            skeleton[attName] = attObj
            console.log "create Skeleton attribute #{attName}"



    start :() ->
        @server = dnode(@serverObj)
        @server.listen(@rmiPort)
        console.log "start rmi service on #{@rmiPort}"

    # options {host:,port:}
    createStub : (options,callback) ->
        try
            new StubObject(options,callback)
        catch e
            callback e, null
        
        

        
module.exports=RmiService
    
