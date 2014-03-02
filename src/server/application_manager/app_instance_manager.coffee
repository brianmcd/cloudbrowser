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
        @counter = 0
        @appInstances  = {}
        {@permissionManager} = @server
        @weakRefsToAppInstances = {}

    create : (user, callback, id = @generateID(), name = @generateName()) ->
        @appInstances[id] =
            new AppInstance
                id    : id
                app   : @app
                obj   : @appInstanceProvider.create()
                name  : name
                owner : user
                server : @server
        appInstance =
            @weakRefsToAppInstances[id] = Weak(@appInstances[id], cleanupStates(id))
        @setupProxyEventEmitter(appInstance)
        @setupAutomaticStore(appInstance)
        @permissionManager.addAppInstancePermRec
            user        : user
            mountPoint  : @app.getMountPoint()
            permission  : 'own'
            appInstanceID : id
            callback : (err, appInstancePermRec) =>
                return callback?(err) if err
                callback?(null, appInstance)
                @emit('add', id)

    loadFromDbRec : (appInstanceRec) ->
        {obj, owner, id, name, readerwriters, dateCreated} = appInstanceRec
        if @find(id) then return
        obj = @appInstanceProvider.load(obj)
        owner = new User(owner._email)
        @appInstances[id] = new AppInstance
            id            : id
            app           : @app
            obj           : obj
            name          : name
            owner         : owner
            dateCreated   : dateCreated
            readerwriters : readerwriters
            server        : @server
        appInstance = @weakRefsToAppInstances[id] =
            Weak(@appInstances[id], cleanupStates(id))
        @setupProxyEventEmitter(appInstance)
        @autoStoreID = @setupAutomaticStore(appInstance)

    # Stores to the database every 5 seconds
    setupAutomaticStore : (appInstance) ->
        intervalID = setInterval () =>
            appInstance.store (obj) =>
                @appInstanceProvider.store(obj)
        , 5000
        appInstance.setAutoStoreID(intervalID)

    setupProxyEventEmitter : (appInstance) ->
        if @app.isAuthConfigured()
            appInstance.on "share", (user) =>
                @emit("share", appInstance.getID(), user)

    find : (id) ->
        return @weakRefsToAppInstances[id]

    remove : (id, user, callback) ->
        appInstance = @find(id)
        if not appInstance then return
        Async.waterfall [
            (next) ->
                appInstance.close(user, next)
            (next) =>
                @emit('remove', id)
                delete @weakRefsToAppInstances[id]
                delete @appInstances[id]
                Async.each appInstance.getAllUsers()
                , (user, callback) =>
                    @permissionManager.rmAppInstancePermRec
                        user          : user
                        mountPoint    : @app.getMountPoint()
                        appInstanceID : id
                        callback      : callback
                , next
        ], callback

    generateName : () ->
        return @counter++

    generateID : () ->
        id = Hat()
        while @find(id)
            id = Hat()
        return id

module.exports = AppInstanceManager
