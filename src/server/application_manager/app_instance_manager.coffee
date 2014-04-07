Weak           = require('weak')
Hat            = require('hat')
User           = require('../user')
Async          = require('async')
AppInstance    = require('./app_instance')
{EventEmitter} = require('events')

cleanupStates = (id) ->
    return () ->
        console.log "[Application Instance Manager] - Garbage collected appliation instance #{id}"

class AppInstanceManager extends EventEmitter
    constructor : (@appInstanceProvider, @server, @app) ->
        {@permissionManager, @uuidService} = @server
        @weakRefsToAppInstances = {}
        @userToAppInstances = {}
        @appInstances  = {}

    getAppInstance : (callback) ->
        if not @weakRefToAppInstance?
            @_createAppInstance(null, (err, instance)=>
                if err?
                    return callback err                
                @weakRefToAppInstance = instance
                @appInstance = @appInstances[@weakRefToAppInstance.id]
                callback null, instance
            )
        else
            callback null, @weakRefToAppInstance

    getUserAppInstance : (user, callback) ->
        if not user?
            throw new Error('should specify user for getUserAppInstance')
        email = if user._email? then user._email else user
        if not @userToAppInstances[email]?
            @_createAppInstance(user,(err, instance)=>
                if err?
                    return callback err
                @userToAppInstances[email] = instance
                callback null, instance    
            )
            
        else
            callback null, @userToAppInstances[email]

    #TODO usually when we create appInstance, we want a brwoser as well, it 
    #would be nice to create a browser here?
    _createAppInstance :(user, callback) ->
        id = @uuidService.getId()
        appInstance = new AppInstance ({
            id : id
            app : @app
            obj : @appInstanceProvider?.create()
            owner : if user? then user else @app.getOwner()
            server : @server
        })
        
        @app._masterApp.registerAppInstance(@server.config.id, id, 
            (err, masterAppInstance)=>
                if err?
                    return callback err
                @appInstances[id] = appInstance
                weakRefToAppInstance = Weak(appInstance, cleanupStates(id))
                @weakRefsToAppInstances[id] = weakRefToAppInstance

                console.log "create appinstance #{id} for #{@app.mountPoint}"

                appInstance.setMasterInstance(masterAppInstance)
                callback null, weakRefToAppInstance
            )
        

    newAppInstance : (callback) ->
        if @app.getInstantiationStrategy() isnt 'default'
            return callback new Error('newAppInstance method is only for default initiation strategy')
        @_createAppInstance(null, callback)

    create :(user, callback) ->
        if not @app.isMultiInstance()
            return callback new Error('create method is only for multiInstance initiation strategy')        
        @_createAppInstance(user, callback)



    find : (id) ->
        return @weakRefsToAppInstances[id]

    # should check permission, etc.
    findBrowser : (appInstanceId, vBrowserId) ->
        appInstance = @find(appInstanceId)
        if appInstance?
            return appInstance.findBrowser(vBrowserId)
        return null
        
    remove : (id, user, callback) ->
        console.log "remove appInstance not implemented #{id}"

    get : () ->
        return @weakRefsToAppInstances


module.exports = AppInstanceManager
