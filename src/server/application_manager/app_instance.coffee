{EventEmitter}       = require('events')

Async                = require('async')
Weak                 = require('weak')
debug                = require('debug')

VirtualBrowser       = require('../virtual_browser')
SecureVirtualBrowser = require('../virtual_browser/secure_virtual_browser')
User                 = require('../user')
cloudbrowserError    = require('../../shared/cloudbrowser_error')

# Defining callback at the highest level
# see https://github.com/TooTallNate/node-weak#weak-callback-function-best-practices
# Dummy callback, does nothing
cleanupBserver = (id) ->
    return () ->
        console.log "[Browser Manager] - Garbage collected vbrowser #{id}"

logger = debug("cloudbrowser:worker:appins")

class AppInstance extends EventEmitter
    __r_skip :['app','browsers','weakrefsToBrowsers', 'browser',
                'weakrefToBrowser', 'server', 'obj', 'uuidService']
    constructor : (options) ->
        {@app
        , @obj
        , owner
        , @id
        , readerwriters
        , @dateCreated,
        @server } = options
        @name = @id
        {@uuidService} = @server
        @workerId = @server.config.id
        if not @dateCreated then @dateCreated = new Date()
        if owner?
            @owner = if owner instanceof User then owner else new User(owner._email)
        @readerwriters = []
        if readerwriters then for readerwriter in readerwriters
            @addReaderWriter(new User(readerwriter._email))
        @browsers = {}
        @weakrefsToBrowsers = {}

        # TODO we need to remove listners from a browser when the browser is
        # closed
        @_eventbus = new EventEmitter()


    findBrowser : (id) ->
        @weakrefsToBrowsers[id]

    addBrowser : (vbrowser) ->
        id = vbrowser.id
        weakrefToBrowser = Weak(vbrowser, cleanupBserver(id))
        # the appinstance is just contianer of browsers, we are interested in getting
        # browser id as soon as we create an appInstance.
        # for singleAppInstance and singleUserInstance, there would be only one browser
        # in appInstance, it is convenient to fileds for the first browser created
        if not @browserId?
            @browserId = id
            @weakrefToBrowser = weakrefToBrowser
            @browser = vbrowser
        @weakrefsToBrowsers[id] = weakrefToBrowser
        @browsers[id] = vbrowser
        logger "appInstance #{@id} emit addBrowser event #{vbrowser.id}"
        @emit('addBrowser', vbrowser)
        return weakrefToBrowser


    _create : (user, callback) ->
        user = User.toUser(user)
        id = @uuidService.getId()
        if not user?
            @_createVirtualBrowser
                type : VirtualBrowser
                id   : id
                callback : callback
            return

        Async.series([
            (cb)=>
                @server.permissionManager.addBrowserPermRec
                    user        : user
                    mountPoint  : @app.getMountPoint()
                    browserID   : id
                    permission  : 'own'
                    callback    : cb
            ,
            (cb)=>
                @_createVirtualBrowser
                    type        : SecureVirtualBrowser
                    id          : id
                    creator     : user
                    permission  : 'own'
                    callback : callback
            ],(err)->
                callback(err)
        )



    _createVirtualBrowser : (options) ->
        startTime = Date.now()
        {id, type, creator, permission, callback} = options
        vbrowser = new type
            id          : id
            server      : @server
            mountPoint  : @app.mountPoint
            creator     : creator
            permission  : permission
            appInstance : this
        vbrowser.load(@app, (err)=>
            return callback(err) if err?
            logger("createBrowser #{@id}:#{id} for #{Date.now()-startTime}ms")
            @addBrowser(vbrowser)
            callback null, vbrowser
        )

    # user: the user try to create browser, callback(err, browser)
    createBrowser : (user, callback) ->
        logger "getBrowser for #{@app.mountPoint} - #{@id}"
        if not @app.isMultiInstance()
            # return the only instance
            if not @weakrefToBrowser
                @_create(user, callback)
            else
                callback null, @weakrefToBrowser
        else
            @_create(user, callback)


    _findReaderWriter : (user) ->
        return c for c in @readerwriters when c.getEmail() is user.getEmail()

    getReaderWriters : () ->
        return @readerwriters

    getID : () -> return @id

    getName : () -> return @name

    getDateCreated : () -> return @dateCreated

    getOwner : () -> return @owner

    getObj : () -> return @obj

    isOwner : (user) ->
        return user.getEmail() is @owner.getEmail()


    isReaderWriter : (user) ->
        return true for c in @readerwriters when c.getEmail() is user.getEmail()

    addReaderWriter : (user, callback) ->
        # the permission records are updated by the caller
        if not @getUserPrevilege(user)
            @readerwriters.push(user)
            callback(null)
            @emit('share', user)
            @app.emitAppEvent({
                name : 'shareAppInstance'
                id : @id
                args : [this, user]
                })
        else
            callback(null)


    getUserPrevilege : (user, callback) ->
        result = null
        # deal with remote objs or strings
        user = User.toUser(user)
        if user?
            if @isOwner(user)
                result = 'own'
            else if @isReaderWriter(user)
                result = 'readwrite'

        if callback?
            logger("appinstance #{@id} getUserPrevilege: #{user.getEmail()} is #{result}")
            callback null, result
        else
            return result


    removeBrowser : (browserId, user, callback) ->
        console.log "appInstance #{@id} : removeBrowser #{browserId}"
        browser = @findBrowser(browserId)
        if browser
            if browser.isOwner and not browser.isOwner(user)
                return callback(new Error("Permission denied : delete browser #{browserId}"))
            @__deleteBrowserReferences(browserId)
            @emit('removeBrowser', browserId)
            callback null
            browser.close()
        else
            console.log "appInstance #{@id} : cannot find #{browserId}"
            callback(new Error("Cannot find browser #{browserId}"))

    __deleteBrowserReferences : (browserId)->
        if @browser and @browser.id is browserId
            @browser = null
            @weakrefToBrowser = null
        delete @browsers[browserId]
        delete @weakrefsToBrowsers[browserId]


    close : (user, callback) ->
        # the user could be a remote object
        user = User.toUser(user)
        if not @isOwner(user)
            return callback(new Error('Permission denied: only owner has the permission to close a appInstance'))
        @app.unregisterAppInstance(@id, (err)=>
            return callback(err) if err?
            @removeAllListeners()
            callback null
            for browserId, browser of @browsers
                browser.close()
            )



    store : (getStorableObj, callback) ->
        console.log "store not implemented"

    getUsers : (callback) ->
        callback null, {
            owners : [@owner]
            readerwriters : @readerwriters
        }

    # all the browsers are in local, it can be called in sync or async style
    getAllBrowsers : (callback) ->
        if callback?
            return callback null, @weakrefsToBrowsers

        return @weakrefsToBrowsers

    getBrowsers : (idList, callback)->
        result = []
        for id in idList
            if @browsers[id]?
                result.push(@browsers[id])
        callback null, result

module.exports = AppInstance
