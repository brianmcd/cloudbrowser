Async = require('async')
Weak           = require('weak')
{EventEmitter} = require('events')
VirtualBrowser      = require('../virtual_browser')
SecureVirtualBrowser = require('../virtual_browser/secure_virtual_browser')
User           = require('../user')
cloudbrowserError = require('../../shared/cloudbrowser_error')

# Defining callback at the highest level
# see https://github.com/TooTallNate/node-weak#weak-callback-function-best-practices
# Dummy callback, does nothing
cleanupBserver = (id) ->
    return () ->
        console.log "[Browser Manager] - Garbage collected vbrowser #{id}"

class AppInstance extends EventEmitter
    __r_skip :['app', 'browsers', 'browser', 'readerwriters','weakrefsToBrowsers',
                'weakrefToBrowser', 'server', 'obj', 'uuidService']
    constructor : (options) ->
        {@app
        , @obj
        , owner
        , @id
        , readerwriters
        , @dateCreated,
        @server } = options
        {@uuidService} = @server
        if not @dateCreated then @dateCreated = new Date()
        if owner?
            @owner = if owner instanceof User then owner else new User(owner._email)
        @readerwriters = []
        if readerwriters then for readerwriter in readerwriters
            @addReaderWriter(new User(readerwriter._email))
        @browsers = {}
        @weakrefsToBrowsers = {}


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
        return weakrefToBrowser


    _create : (user) ->
        vbrowser = null
        if @app.isAuthConfigured()
            vbrowser = @_createVirtualBrowser
                type        : SecureVirtualBrowser
                id          : @uuidService.getId()
                creator     : @owner
                permission  : 'own'
        else 
            vbrowser = @_createVirtualBrowser
                type : VirtualBrowser
                id   : @uuidService.getId()
        # retrun weak reference
        console.log "createBrowser #{vbrowser.id} for #{@app.mountPoint} - #{@id}"
        return @addBrowser(vbrowser)
        

    _createVirtualBrowser : (browserInfo) ->
        {id, type, creator, permission} = browserInfo
        vbrowser = new type
            id          : id
            server      : @server
            mountPoint  : @app.mountPoint
            creator     : creator
            permission  : permission
            appInstance : this
        vbrowser.load(@app)
        return vbrowser

    # user: the user try to create browser, callback(err, browser)
    createBrowser : (user, callback) ->
        console.log "getBrowser for #{@app.mountPoint} - #{@id}"
        if not @app.isMultiInstance()
            # return the only instance
            if not @weakrefToBrowser
                @_create(user)
            if callback?
                return callback(@weakrefToBrowser)
            return @weakrefToBrowser
        else
            browser = @_create(user)
            if callback?
                return callback null, browser
            return browser

    _findReaderWriter : (user) ->
        return c for c in @readerwriters when c.getEmail() is user.getEmail()

    getReaderWriters : () ->
        return @readerwriters

    getID : () -> return @id

    getName : () -> return @id

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


    removeBrowser : (bserver, user, callback) ->
        console.log "removeBrowser not implemented #{bserver.id}"

    removeAllBrowsers : (user, callback) ->
        console.log "removeAllBrowsers not implemented"

    close : (user, callback) ->
        console.log "close not implemented"

    store : (getStorableObj, callback) ->
        console.log "store not implemented"

    getAllUsers : () ->
        users = []
        users.push(@owner)
        return users.concat(@readerwriters)

    getAllBrowsers : () ->
        return @weakrefsToBrowsers
    



module.exports = AppInstance
