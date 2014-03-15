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

    getAppInstance : () ->
        if not @weakRefToAppInstance?
            @weakRefToAppInstance = @_createAppInstance()
            @appInstance = @appInstances[@weakRefToAppInstance.id]
        return @weakRefToAppInstance

    getUserAppInstance : (user) ->
        if not user?
            throw new Error('should specify user for getUserAppInstance')
        email = if user._email? then user._email else user
        if not @userToAppInstances[email]?
            weakRefToAppInstance = @_createAppInstance(user)
            @userToAppInstances[email] = weakRefToAppInstance
        return @userToAppInstances[email]

    _createAppInstance :(user) ->
        id = @uuidService.getId()
        appInstance = new AppInstance ({
            id : id
            app : @app
            obj : @appInstanceProvider?.create()
            owner : if user? then user else @app.getOwner()
            server : @server
            })
        @appInstances[id] = appInstance
        weakRefToAppInstance = Weak(appInstance, cleanupStates(id))
        @weakRefsToAppInstances[id] = weakRefToAppInstance
        return weakRefToAppInstance

    newAppInstance : () ->
        if @app.getInstantiationStrategy() isnt 'default'
            throw new Error('newAppInstance method is only for default initiation strategy')
        return @_createAppInstance()

    create :(user, callback) ->
        if not @app.isMultiInstance()
            throw new Error('create method is only for multiInstance initiation strategy')        
        callback null, @_createAppInstance(user)



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
