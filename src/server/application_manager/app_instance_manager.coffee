Weak           = require('weak')
Hat            = require('hat')
Async          = require('async')
AppInstance    = require('./app_instance')
{EventEmitter} = require('events')

cleanupStates = (id) ->
    return () ->
        console.log "[Application Instance Manager] - Garbage collected appliation instance #{id}"

class AppInstanceManager extends EventEmitter
    constructor : (@template, @permissionManager, @app) ->
        @counter = 0
        @appInstances  = {}
        @weakRefsToAppInstances = {}

    create : (user, callback, id = @generateID(), name = @generateName()) ->
        @appInstances[id] = new AppInstance(@app, @template, user, id, name)
        @weakRefsToAppInstances[id] = Weak(@appInstances[id], cleanupStates(id))
        @setupProxyEventEmitter(@weakRefsToAppInstances[id])
        @permissionManager.addAppInstancePermRec
            user        : user
            mountPoint  : @app.getMountPoint()
            permission  : 'own'
            appInstanceID : id
            callback : (err, appInstancePermRec) =>
                return callback?(err) if err
                callback?(null, @weakRefsToAppInstances[id])
                @emit('add', id)

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
                delete @weakRefsToAppInstances[id]
                delete @appInstances[id]
                @emit 'remove', id
                @permissionManager.rmAppInstancePermRec
                    user          : user
                    mountPoint    : @app.getMountPoint()
                    appInstanceID : id
                    callback      : next
        ], callback

    generateName : () ->
        return @counter++

    generateID : () ->
        id = Hat()
        while @find(id)
            id = Hat()
        return id

module.exports = AppInstanceManager
