Async = require('async')
{EventEmitter} = require('events')
User           = require('../user')
cloudbrowserError = require('../../shared/cloudbrowser_error')

class AppInstance extends EventEmitter
    constructor : (options) ->
        {@app
        , @obj
        , owner
        , @id
        , @name
        , readerwriters
        , @dateCreated,
        @server } = options
        if not @dateCreated then @dateCreated = new Date()
        @owner = if owner instanceof User then owner else new User(owner._email)
        @readerwriters = []
        if readerwriters then for readerwriter in readerwriters
            @addReaderWriter(new User(readerwriter._email))
        @browsers = []

    _findReaderWriter : (user) ->
        return c for c in @readerwriters when c.getEmail() is user.getEmail()

    getReaderWriters : () ->
        return @readerwriters

    getID : () -> return @id

    getName : () -> return @name

    setName : (name) -> @name = name

    getDateCreated : () -> return @dateCreated

    getOwner : () -> return @owner

    getObj : () -> return @obj

    isOwner : (user) ->
        return user.getEmail() is @owner.getEmail()

    isReaderWriter : (user) ->
        return true for c in @readerwriters when c.getEmail() is user.getEmail()

    addReaderWriter : (user) ->
        if @isOwner(user) or @isReaderWriter(user) then return
        @readerwriters.push(user)
        @emit('share', user)

    createBrowser : (user, callback) ->
        if @isOwner(user) or @isReaderWriter(user)
            Async.waterfall [
                (next) =>
                    @app.browsers.create
                        user     : user
                        callback : next
                        preLoadMethod : (bserver) => bserver.setAppInstance(@)
                (bserver, next) =>
                    @browsers.push(bserver)
                    next(null, bserver)
            ], callback
        else callback(cloudbrowserError('PERM_DENIED'))

    removeBrowser : (bserver, user, callback) ->
        {id} = bserver
        Async.waterfall [
            (next) =>
                @app.browsers.close(bserver, user, next)
            (next) =>
                for browser in @browsers when browser.id is id
                    idx = @browsers.indexOf(browser)
                    @browsers.splice(idx, 1)
                    break
                next(null)
        ], callback

    removeAllBrowsers : (user, callback) ->
        if @isOwner(user) or @isReaderWriter(user)
            Async.each @browsers
            , (browser, callback) =>
                @app.browsers.close(browser, user, callback)
            , callback
        else callback(cloudbrowserError('PERM_DENIED'))

    setAutoStoreID : (intervalID) ->
        @autoStoreID = intervalID

    descheduleAutoStore : () ->
        clearInterval(@autoStoreID)

    close : (user, callback) ->
        if @isOwner(user)
            @removeAllListeners()
            @removeAllBrowsers(user, callback)
            @descheduleAutoStore()
        else callback(cloudbrowserError('PERM_DENIED'))

    store : (getStorableObj, callback) ->
        dbRec = {}
        excluded = ['app', '_events', 'browsers']
        for own k, v of this
            if typeof v isnt "function" and excluded.indexOf(k) is -1
                dbRec[k] = v
        dbRec.obj = getStorableObj(@obj)

        return callback?(cloudbrowserError("INVALID_STORE")) if not dbRec.obj

        appInstanceRec = {}
        appInstanceRec["appInstances." + @id] = dbRec

        
        mongoInterface = @server.mongoInterface
        searchKey = {mountPoint : @app.getMountPoint()}
        mongoInterface.setApp(searchKey, appInstanceRec, callback)

    getAllUsers : () ->
        users = []
        users.push(@owner)
        return users.concat(@readerwriters)

module.exports = AppInstance
