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

    # user is always string
    createAppInstance : (user) ->
        if user? and typeof user isnt 'string'
            throw new Error("User #{user} should be string")

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
        if not user? or not user._email?
            throw new Error("should specify user for getUserAppInstance : #{user}")
        email = user._email
            
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
        
    # called by api, need to register the new appInstance to master
    create :(user, callback) ->
        if not @app.isMultiInstance()
            throw new Error('create method is only for multiInstance initiation strategy')        
        appInstance = @_createAppInstance(user)
        @_masterApp.regsiterAppInstance(@server.config.id, appInstance, (err)=>
            if err?
                @_removeAppInstance(appInstance)
                return callback err
            callback err, appInstance
        )
        
    _removeAppInstance : (appInstance) ->
        delete @appInstances[appInstance.id]
        delete @weakRefsToAppInstances[appInstance.id]
        if @appInstance? and @appInstance.id is appInstance.id
            @appInstance = null
            @weakRefToAppInstance = null
        if @appInstance.owner?
            email = @appInstance.owner._email
            ref = @userToAppInstances[email]
            if ref? and ref.id is appInstance.id
                delete @userToAppInstances[email]
        appInstance.close()
            
        
        


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
