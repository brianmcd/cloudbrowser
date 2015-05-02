{EventEmitter} = require('events')

Weak           = require('weak')
Hat            = require('hat')
Async          = require('async')
debug          = require('debug')
lodash         = require('lodash')

User           = require('../user')
AppInstance    = require('./app_instance')


cleanupStates = (id) ->
    return () ->
        console.log "[Application Instance Manager] - Garbage collected appliation instance #{id}"

applogger = debug('cloudbrowser:worker:app')

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
                # the application is configured wrong, create a new instance anyway
                applogger "App #{@app.mountPoint} is SingleInstancePerUser but 
                        did not provide user when calling createAppInstance"
                return @_createAppInstance(user, callback)
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
            owner = User.toUser(user)
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
                if not user?
                    # skip permission manager if we do not have user info
                    next()
                else
                    applogger("go through permissionManager")
                    # FIXME it is crazily slow under some concurrent access
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
                applogger("#{@server.config.id} createAppInstance #{id}")
                callback(null, weakRefToAppInstance)
            )

        
    # called by api, forward the request to master, the master will either find
    # a existing appInstance or create a new one.
    # master will register the created appInstance before
    # invoking this callback
    create :(user, callback) ->
        @_masterApp.createUserAppInstance(user, callback)

    # create a new appInstance in local and register it with master
    # can only be called by multiInstance apps
    createAndRegister : (user, callback)->
        if @app.isSingleInstance() or @app.isSingleInstancePerUser()
            return callback(new Error("createAndRegister only support multiIntance"))
        @_createAppInstance(user, (err, appInstance)=>
            return callback(err) if err?
            @_masterApp.regsiterAppInstance(@server.config.id, appInstance, callback)
        )
        
        
    _removeAppInstance : (appInstanceId) ->
        appInstance = @appInstances[appInstanceId]
        return if not appInstance?
        delete @appInstances[appInstanceId]
        delete @weakRefsToAppInstances[appInstanceId]
        if @appInstance? and @appInstanceId is @appInstance.id
            @appInstance = null
        if appInstance.owner?
            email = appInstance.owner._email
            ref = @userToAppInstances[email]
            if ref? and ref.id is appInstanceId
                delete @userToAppInstances[email]

            
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
        
        
    remove : (id, callback) ->
        appIns = @appInstances[id]
        if appIns?
            appIns.close()
            delete @appInstances[id]  
            delete @weakRefsToAppInstances[id]
        callback null

    get : () ->
        return @weakRefsToAppInstances

    stop : (callback)->
        appInstances = lodash.values(@appInstances)
        Async.each(
            appInstances, 
            (appInstance, appInstanceCb)->
                appInstance.stop(appInstanceCb)
            ,
            (err)=>
                applogger("error stop appinstaces for #{@app.mountPoint} #{err}") if err?
                callback(err)
        )

    close : (callback)->
        appInstances = lodash.values(@appInstances)
        Async.each(
            appInstances, 
            (appInstance, appInstanceCb)->
                appInstance.close2(appInstanceCb)
            ,
            (err)=>
                applogger("error close appinstaces for #{@app.mountPoint} #{err}") if err?
                @appInstances = null
                @weakRefsToAppInstances = null
                callback(err)
        )
        

module.exports = AppInstanceManager
