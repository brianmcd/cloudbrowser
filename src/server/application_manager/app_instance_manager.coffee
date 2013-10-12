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
        @emit('create', @weakRefsToAppInstances[id])
        @permissionManager.addAppInstancePermRec
            user        : user
            mountPoint  : @app.getMountPoint()
            permissions : {own : true}
            appInstanceID : id
            callback : (err, appInstancePermRec) =>
                if err then callback?(err)
                callback?(null, @weakRefsToAppInstances[id])

    find : (id) ->
        return @weakRefsToAppInstances[id]

    remove : (id, user, callback) ->
        state = @find(id)
        if not state then return
        Async.waterfall [
            (next) ->
                state.close(user, next)
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
