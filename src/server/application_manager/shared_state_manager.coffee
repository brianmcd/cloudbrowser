Weak           = require('weak')
Hat            = require('hat')
Async          = require('async')
SharedState    = require('./shared_state')
{EventEmitter} = require('events')

cleanupStates = (id) ->
    return () ->
        console.log "[State Manager] - Garbage collected state #{id}"

class SharedStateManager extends EventEmitter
    constructor : (@template, @permissionManager, @app) ->
        @counter = 0
        @states  = {}
        @weakRefsToStates = {}

    create : (user, callback, id = @generateID(), name = @generateName()) ->
        @states[id] = new SharedState(@app, @template, user, id, name)
        @weakRefsToStates[id] = Weak(@states[id], cleanupStates(id))
        @emit('create', @weakRefsToStates[id])
        @permissionManager.addSharedStatePermRec
            user        : user
            mountPoint  : @app.getMountPoint()
            permissions : {own : true}
            sharedStateID : id
            callback : (err, sharedStatePermRec) =>
                if err then callback?(err)
                callback?(null, @weakRefsToStates[id])

    find : (id) ->
        return @weakRefsToStates[id]

    remove : (id, user, callback) ->
        state = @find(id)
        if not state then return
        Async.waterfall [
            (next) ->
                state.close(user, next)
            (next) =>
                delete @weakRefsToStates[id]
                delete @states[id]
                @emit 'remove', id
                @permissionManager.rmSharedStatePermRec
                    user          : user
                    mountPoint    : @app.getMountPoint()
                    sharedStateID : id
                    callback      : next
        ], callback

    generateName : () ->
        return @counter++

    generateID : () ->
        id = Hat()
        while @find(id)
            id = Hat()
        return id

module.exports = SharedStateManager
