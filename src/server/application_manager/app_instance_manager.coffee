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
        if not @appInstance?
            #not in local, query master
            @_masterApp.getAppInstance(callback)
        else
            callback null, @appInstance



    # actual create a new instance in local
    createAppInstance : (user, callback) ->
        user = User.getEmail(user)
        
        if @app.isSingleInstance()
            # check if we had it
            if not @appInstance?
                return @_createAppInstance(user, (err, instance) =>
                        return callback(err) if err?
                        @appInstance = instance
                        callback null, instance
                    )
            return callback null, @appInstance
        else if @app.isSingleInstancePerUser()
            if not user?
                return callback(new Error('should specify user for getAppInstanceForUser'))
            if not @userToAppInstances[user]?
                return @_createAppInstance(user, (err, instance)=>
                        @userToAppInstances[user] = instance
                        callback null, instance
                )
            return callback null, @userToAppInstances[user]
        else    
            return @_createAppInstance(user, callback)


    getUserAppInstance : (user, callback) ->
        if not user? or not user._email?
            throw new Error("should specify user for getUserAppInstance : #{user}")
        email = user._email
            
        if not @userToAppInstances[email]?
            # query master
            @_masterApp.getUserAppInstance(email, callback)
        else
            callback null, @userToAppInstances[email]

        
    
    _createAppInstance :(user, callback) ->
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
        # usually when we create appInstance, we want a browser as well
        Async.series([
            (next)->
                appInstance.createBrowser(user, next)
            (next)=>
                @permissionManager.addAppInstancePermRec
                    user        : owner
                    mountPoint  : @app.getMountPoint()
                    permission  : 'own'
                    appInstanceID : id
                    callback : next
            ],(err)=>
                return callback(err) if err
                @appInstances[id] = appInstance
                weakRefToAppInstance = Weak(appInstance, cleanupStates(id))
                @weakRefsToAppInstances[id] = weakRefToAppInstance                
                callback(null, weakRefToAppInstance)

            )

        
    # called by api, need to register the new appInstance to master
    create :(user, callback) ->
        @_masterApp.createUserAppInstance(user, callback)
        
        
    _removeAppInstance : (appInstance) ->
        delete @appInstances[appInstance.id]
        delete @weakRefsToAppInstances[appInstance.id]
        if @appInstance? and @appInstance.id is appInstance.id
            @appInstance = null
        if @appInstance.owner?
            email = @appInstance.owner._email
            ref = @userToAppInstances[email]
            if ref? and ref.id is appInstance.id
                delete @userToAppInstances[email]
        appInstance.close()
            
    # find in local
    find : (id) ->
        return @weakRefsToAppInstances[id]

    # query the master
    findInstance : (id, callback) ->
        @_masterApp.findInstance(id, callback)


    # should check permission, etc.
    findBrowser : (appInstanceId, vBrowserId) ->
        appInstance = @find(appInstanceId)
        if appInstance?
            return appInstance.findBrowser(vBrowserId)
        return null

    # get the browsers by id
    getBrowsers : (idList, callback) ->
        Async.waterfall([
            (next)=>
                @_masterApp.getAllAppInstances(next)
            (appInstances, next) =>
                result = []
                Async.each(
                    appInstances, 
                    (appInstance, appInstanceCb)->
                        appInstance.getBrowsers(idList, (err, browsers)->
                            return appInstanceCb(err) if err?
                            for b in browsers
                                result.push(b)
                            appInstanceCb null
                            
                            )
                    ,
                    (err)->
                        return next(err) if err?
                        next null, result
                )
        ]
        ,(err, result)->
            return callback(err) if err?
            callback null, result
            )
        
        
    remove : (id, user, callback) ->
        console.log "remove appInstance not implemented #{id}"

    get : () ->
        return @weakRefsToAppInstances


module.exports = AppInstanceManager
