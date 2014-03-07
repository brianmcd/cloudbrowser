Components = require('../server/components')
Async      = require('async')
User       = require('../server/user')
cloudbrowserError = require('../shared/cloudbrowser_error')
{areArgsValid} = require('./utils')

# Permission checks are included wherever possible and a note is made if
# missing. Details like name, id, url etc. are available to everybody.

###*
    Event to indicate that the current browser has been shared with 
    another user
    @event Browser#share
###
###*
    Event to indicate that the current browser has been renamed
    @event Browser#rename
    @type {String}
###
###*
    API for  browsers (internal object).
    @class Browser
    @param {Object}           options 
    @param {User}             options.userCtx The current user.
    @param {Cloudbrowser}     options.cbCtx   The cloudbrowser API object.
    @param {BrowserServer}    options.browser The browser.
    @fires Browser#share
    @fires Browser#rename
###
class Browser

    # Private Properties inside class closure
    _pvts = []

    constructor : (options) ->
        # Defining @_idx as a read-only property
        Object.defineProperty this, "_idx",
            value : _pvts.length

        {browser, cbCtx, userCtx} = options

        _pvts.push
            bserver : browser
            userCtx : userCtx
            cbCtx   : cbCtx

        # Freezing the prototype to protect from unauthorized changes
        # by people using the API
        Object.freeze(this.__proto__)
        Object.freeze(this)

    ###*
        Gets the ID of the instance.
        @method getID
        @return {Number}
        @instance
        @memberOf Browser
    ###
    getID : () ->
        return _pvts[@_idx].bserver.getID()

    ###*
        Gets the url of the instance.
        @method getURL
        @return {String}
        @instance
        @memberOf Browser
    ###
    getURL : () ->
        {bserver}  = _pvts[@_idx]
        id         = bserver.getID()
        mountPoint = bserver.getMountPoint()
        {domain, port} = bserver.server.config
        return "http://#{domain}:#{port}#{mountPoint}/browsers/#{id}/index"

    ###*
        Gets the date of creation of the instance.
        @method getDateCreated
        @return {Date}
        @instance
        @memberOf Browser
    ###
    getDateCreated : () ->
        return _pvts[@_idx].bserver.getDateCreated()

    ###*
        Gets the name of the instance.
        @method getName
        @return {String}
        @instance
        @memberOf Browser
    ###
    getName : () ->
        return _pvts[@_idx].bserver.getName()

    ###*
        Creates a new component
        @method createComponent
        @param {String}  name    The registered name of the component.          
        @param {DOMNode} target  The DOM node in which the component will be embedded.         
        @param {Object}  options Extra options to customize the component.          
        @return {DOMNode}
        @instance
        @memberof Browser
    ###
    createComponent : (name, target, options) ->
        return if typeof name isnt "string" or not target or not target.__nodeID
        {bserver} = _pvts[@_idx]
        browser  = bserver.getBrowser()
        targetID = target.__nodeID

        if browser.components[targetID]
            return(cloudbrowserError("COMPONENT_EXISTS"))
        
        # Get the component constructor
        Ctor = Components[name]
        if not Ctor then return(cloudbrowserError("NO_COMPONENT", "-#{name}"))

        rpcMethod = (method, args) ->
            browser.emit 'ComponentMethod',
                target : target
                method : method
                args   : args
                
        # Mountpoint needed for authentication in case of
        # the file uploader component
        options.cloudbrowser = {mountPoint : bserver.getMountPoint()}
        options.cbServer = bserver.server
        # Create the component
        comp = browser.components[targetID] =
            new Ctor(options, rpcMethod, target)
        clientComponent = [name, targetID, comp.getRemoteOptions()]
        browser.clientComponents.push(clientComponent)
        browser.emit('CreateComponent', clientComponent)
        return target

    ###*
        Gets the Application API object.
        @method getAppConfig
        @return {AppConfig}
        @memberof Browser
        @instance
    ###
    getAppConfig : () ->
        {bserver, cbCtx, userCtx} = _pvts[@_idx]
        mountPoint = bserver.getMountPoint()
        AppConfig  = require("./application_config")
        app = bserver.server.applicationManager.find(mountPoint)

        return new AppConfig({
            cbServer : bserver.server
            cbCtx   : cbCtx
            userCtx : userCtx
            app     : app
        })

    ###*
        Closes the  browser.
        @method close
        @memberof Browser
        @instance
        @param {errorCallback} callback
    ###
    close : (callback) ->
        {bserver, userCtx} = _pvts[@_idx]
        
        appManager = bserver.server.applicationManager
        app = appManager.find(bserver.getMountPoint())

        if userCtx.getEmail() is "public"
            app.browsers.close(bserver)
        else
            appInstance = bserver.getAppInstance()
            if appInstance
                appInstance.removeBrowser(bserver, userCtx, callback)
            else
                app.browsers.close(bserver, userCtx, callback)

    ###*
        Redirects all clients that are connected to the current
        instance to the given URL.
        @method redirect
        @param {String} url
        @memberof Browser
        @instance
    ###
    redirect : (url) ->
        _pvts[@_idx].bserver.redirect(url)

    ###*
        Gets the email ID that is stored in the session
        @method getResetEmail
        @param {emailCallback} callback
        @memberof Browser
        @instance
    ###
    getResetEmail : (callback) ->
        {bserver} = _pvts[@_idx]
        
        mongoInterface = bserver.server.mongoInterface

        bserver.getFirstSession (err, session) ->
            return callback(err) if err
            callback(null,
                SessionManager.findPropOnSession(session, 'resetuser'))

    ###*
        Gets the user that created the instance.
        @method getCreator
        @return {String}
        @instance
        @memberof Browser
    ###
    getCreator : () ->
        {bserver} = _pvts[@_idx]
        return bserver.getCreator()?.getEmail()

    ###*
        Registers a listener for an event on the  browser instance.
        @method addEventListener
        @param {String} event
        @param {errorCallback} callback 
        @instance
        @memberof Browser
    ###
    addEventListener : (event, callback) ->
        if typeof callback isnt "function" then return

        validEvents = ["share", "rename", "connect", "disconnect"]
        if typeof event isnt "string" or validEvents.indexOf(event) is -1
            return

        {bserver} = _pvts[@_idx]

        if @isAssocWithCurrentUser()
            switch event
                when "share"
                    bserver.on event, (userInfo) ->
                        newUserInfo = {}
                        newUserInfo.role = userInfo.role
                        newUserInfo.user = userInfo.user.getEmail()
                        callback(newUserInfo)
                else
                    bserver.on(event, callback)

    ###*
        Checks if the current user has some permission
        associated with this browser
        @method isAssocWithCurrentUser
        @return {Bool}
        @instance
        @memberof Browser
    ###
    isAssocWithCurrentUser : () ->
        {bserver, userCtx} = _pvts[@_idx]
        appConfig = @getAppConfig()
        if not appConfig.isAuthConfigured() or
            bserver.isOwner(userCtx) or
            bserver.isReaderWriter(userCtx) or
            bserver.isReader(userCtx) or
            appConfig.isOwner()
                return true
        else return false

    ###*
        Gets all users that have the permission only to read and
        write to the instance.
        @method getReaderWriters
        @return {Array<User>}
        @instance
        @memberof Browser
    ###
    getReaderWriters : () ->
        {bserver} = _pvts[@_idx]
        # There will not be any users in case authentication has
        # not been enabled
        return if typeof bserver.getReaderWriters isnt "function"
        if @isAssocWithCurrentUser()
            users = []
            users.push(rw.getEmail()) for rw in bserver.getReaderWriters()
            return users

    ###*
        Gets all users that have the permission only to read
        @method getReaders
        @return {Array<User>}
        @instance
        @memberof Browser
    ###
    getReaders : () ->
        {bserver} = _pvts[@_idx]
        # There will not be any users in case authentication has
        # not been enabled
        return if typeof bserver.getReaders isnt "function"
        if @isAssocWithCurrentUser()
            users = []
            users.push(rw.getEmail()) for rw in bserver.getReaders()
            return users

    ###*
        Gets all users that are the owners of the instance
        There is a separate method for this as it is faster to get only the
        number of owners than to construct a list of them using
        getOwners and then get that number.
        @method getOwners
        @return {Array<User>}
        @instance
        @memberof Browser
    ###
    getOwners : () ->
        {bserver} = _pvts[@_idx]
        # There will not be any users in case authentication has
        # not been enabled
        return if typeof bserver.getOwners isnt "function"
        if @isAssocWithCurrentUser()
            users = []
            users.push(rw.getEmail()) for rw in bserver.getOwners()
            return users

    ###*
        Checks if the user is a reader-writer of the instance.
        @method isReaderWriter
        @param {String} user
        @return {Bool}
        @instance
        @memberof Browser
    ###
    isReaderWriter : (emailID) ->
        {bserver, userCtx} = _pvts[@_idx]
        # There will not be any users in case authentication has
        # not been enabled
        return if typeof bserver.isReaderWriter isnt "function"

        switch arguments.length
            # Check for current user
            when 0 then
            # Check for given user
            when 1
                emailID = arguments[0]
                if not areArgsValid [
                    {item : emailID, type : "string"}
                ] then return
                userCtx = new User(emailID)
            else return

        if @isAssocWithCurrentUser()
            if bserver.isReaderWriter(userCtx) then return true
            else return false

    ###*
        Checks if the user is a reader of the instance.
        @method isReader
        @param {String} emailID
        @return {Bool}
        @memberof Browser
        @instance
    ###
    isReader : (emailID) ->
        {bserver, userCtx} = _pvts[@_idx]
        # There will not be any users in case authentication has
        # not been enabled
        return if typeof bserver.isReader isnt "function"

        switch arguments.length
            # Check for current user
            when 0 then
            # Check for given user
            when 1
                emailID = arguments[0]
                if not areArgsValid [
                    {item : emailID, type : "string"}
                ] then return
                userCtx = new User(emailID)
            else return

        if @isAssocWithCurrentUser()
            if bserver.isReader(userCtx) then return true
            else return false

    ###*
        Checks if the user is an owner of the instance
        @method isOwner
        @param {String} user
        @return {Bool}
        @instance
        @memberof Browser
    ###
    isOwner : () ->
        {bserver, userCtx} = _pvts[@_idx]
        # There will not be any users in case authentication has
        # not been enabled
        return if typeof bserver.isOwner isnt "function"

        switch arguments.length
            # Check for current user
            when 0 then
            # Check for given user
            when 1
                emailID = arguments[0]
                if not areArgsValid [
                    {item : emailID, type : "string"}
                ] then return
                userCtx = new User(emailID)
            else return

        if @isAssocWithCurrentUser()
            if bserver.isOwner(userCtx) then return true
            else return false

    ###*
        Adds a user as a readerwriter of the current browser
        @method addReaderWriter
        @param {String} emailID
        @param {errorCallback} callback
        @instance
        @memberof Browser
    ###
    addReaderWriter : (emailID, callback) ->
        {bserver, userCtx} = _pvts[@_idx]
        return if not areArgsValid [
            {item : emailID, type : "string", action : callback}
        ]
        # There will not be any users in case authentication has
        # not been enabled
        if typeof bserver.addReaderWriter isnt "function"
            return callback?(cloudbrowserError('API_INVALID', "- addReaderWriter"))
        @grantPermissions('readwrite', new User(emailID), callback)

    ###*
        Adds a user as an owner of the current browser
        @method addOwner
        @param {String} emailID
        @param {errorCallback} callback
        @instance
        @memberof Browser
    ###
    addOwner : (emailID, callback) ->
        {bserver, userCtx} = _pvts[@_idx]
        return if not areArgsValid [
            {item : emailID, type : "string", action : callback}
        ]
        # There will not be any users in case authentication has
        # not been enabled
        if typeof bserver.addOwner isnt "function"
            return callback?(cloudbrowserError('API_INVALID', "- addOwner"))
        @grantPermissions('own', new User(emailID), callback)

    ###*
        Adds a user as a reader of the current browser
        @method addReader
        @param {String} emailID
        @param {errorCallback} callback
        @instance
        @memberof Browser
    ###
    addReader : (emailID, callback) ->
        {bserver, userCtx} = _pvts[@_idx]
        return if not areArgsValid [
            {item : emailID, type : "string", action : callback}
        ]
        # There will not be any users in case authentication has
        # not been enabled
        if typeof bserver.addReader isnt "function"
            return callback?(cloudbrowserError('API_INVALID', "- addReader"))
        @grantPermissions('readonly', new User(emailID), callback)

    ###*
        Grants the user a role/permission on the browser.
        @method grantPermissions
        @param {String} permission
        @param {User} user 
        @param {errorCallback} callback 
        @instance
        @memberof Browser
    ###
    grantPermissions : (permission, user, callback) ->
        {bserver, userCtx} = _pvts[@_idx]
        {mountPoint, id}    = bserver
        
        permissionManager = bserver.server.permissionManager

        Async.waterfall [
            (next) ->
                if not bserver.isOwner(userCtx)
                    return next(cloudbrowserError("PERM_DENIED"))
                # Add the user -> bserver lookup reference
                else permissionManager.addBrowserPermRec
                    user        : user
                    mountPoint  : mountPoint
                    browserID   : id
                    permission  : permission
                    callback    : next
        ], (err, browserRec) ->
            # Add the bserver -> user lookup reference
            if err then return callback(err)
            switch permission
                when 'own'
                    bserver.addOwner(user)
                when 'readwrite'
                    bserver.addReaderWriter(user)
                when 'readonly'
                    bserver.addReader(user)
            callback(null)
            
    ###*
        Renames the instance.
        @method rename
        @param {String} newName
        @fires Browser#rename
        @instance
        @memberof Browser
    ###
    rename : (newName) ->
        if typeof newName isnt "string" then return
        {bserver, userCtx} = _pvts[@_idx]
        if bserver.isOwner(userCtx)
            bserver.setName(newName)
            bserver.emit('rename', newName)

    ###*
        Gets the application instance associated with the current browser
        @method getAppInstanceConfig
        @return {AppInstance}
        @instance
        @memberof Browser
    ###
    getAppInstanceConfig : () ->
        {bserver, cbCtx, userCtx} = _pvts[@_idx]

        appInstance = bserver.getAppInstance()
        if not appInstance then return
        if @isAssocWithCurrentUser()
            AppInstance = require('./app_instance')
            return new AppInstance
                cbCtx       : cbCtx
                userCtx     : userCtx
                appInstance : appInstance
                cbServer    : bserver.server

    ###*
        Gets the local state with the current browser
        @method getLocalState
        @return {Object} Custom object provided by the application in the application state file
        @instance
        @memberof Browser
    ###
    getLocalState : (property) ->
        {bserver} = _pvts[@_idx]
        if @isAssocWithCurrentUser()
            return bserver.getLocalState(property)

    ###*
        Gets information about the users connected to the current browser
        @method getConnectedClients
        @return {Array<{{address: String, email: String}}>}
        @instance
        @memberof Browser
    ###
    getConnectedClients : () ->
        {bserver} = _pvts[@_idx]
        if @isAssocWithCurrentUser()
            return bserver.getConnectedClients()

module.exports = Browser
