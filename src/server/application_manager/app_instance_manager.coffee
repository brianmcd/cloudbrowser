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
        {@_masterApp} = @app
        @weakRefsToAppInstances = {}
        @userToAppInstances = {}
        @appInstances  = {}

    getAppInstance : (callback) ->
        if not @weakRefToAppInstance?
            #not in local, query master
            @_masterApp.getAppInstance(callback)
        else
            callback null, @weakRefToAppInstance

    createAppInstance : (user) ->
        if @app.isSingleInstance()
            if not @weakRefToAppInstance?
                @weakRefToAppInstance = @_createAppInstance(user)
                @appInstance = @appInstances[@weakRefToAppInstance.id]
            return @weakRefToAppInstance
        else if @app.isSingleInstancePerUser()
            if not user?
                throw new Error('should specify user for getAppInstanceForUser')
            if not @userToAppInstances[user]?
                @userToAppInstances[user] = @_createAppInstance(user)
            return @userToAppInstances[user]
        else    
            return @_createAppInstance(user)


    getUserAppInstance : (user, callback) ->
        if not user?
            throw new Error('should specify user for getUserAppInstance')
        email = if user._email? then user._email else user
        if not @userToAppInstances[email]?
            # query master
            @_masterApp.getUserAppInstance(email, callback)
        else
            callback null, @userToAppInstances[email]

        
    
    _createAppInstance :(user) ->
        owner = user
        if user?
            if typeof user is 'string'
                owner = new User(user)
        else
            owner = @app.getOwner()
            
        id = @uuidService.getId()
        appInstance = new AppInstance ({
            id : id
            app : @app
            obj : @appInstanceProvider?.create()
            owner : owner
            server : @server
        })
        # usually when we create appInstance, we want a brwoser as well
        appInstance.createBrowser(user)
        @appInstances[id] = appInstance
        weakRefToAppInstance = Weak(appInstance, cleanupStates(id))
        @weakRefsToAppInstances[id] = weakRefToAppInstance
        return weakRefToAppInstance
        

    newAppInstance : (callback) ->
        if @app.getInstantiationStrategy() isnt 'default'
            throw new Error('newAppInstance method is only for default initiation strategy')
        @_masterApp.getNewAppInstance(callback)

    create :(user) ->
        if not @app.isMultiInstance()
            throw new Error('create method is only for multiInstance initiation strategy')        
        return @_createAppInstance(user)



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
