Components = require('../server/components')
Async      = require('async')
cloudbrowserError = require('../shared/cloudbrowser_error')

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
    @param {Object}                options 
    @param {BrowserServer}         options.browser The  browser.
    @param {cloudbrowser.app.User} options.userCtx The current user.
    @param {Cloudbrowser}          options.cbCtx   The cloudbrowser API object.
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

        browserInfo =
            bserver : browser
            userCtx : userCtx
            cbCtx   : cbCtx

        _pvts.push(browserInfo)

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
        return _pvts[@_idx].bserver.id

    ###*
        Gets the url of the instance.
        @method getURL
        @return {String}
        @instance
        @memberOf Browser
    ###
    getURL : () ->
        {bserver} = _pvts[@_idx]
        {mountPoint, id} = bserver
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
        return _pvts[@_idx].bserver.dateCreated

    ###*
        Gets the name of the instance.
        @method getName
        @return {String}
        @instance
        @memberOf Browser
    ###
    getName : () ->
        return _pvts[@_idx].bserver.name

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
        {bserver} = _pvts[@_idx]
        {browser} = bserver

        # bserver may have been gc'ed
        if not browser then return

        targetID = target.__nodeID

        if browser.components[targetID]
            return(cloudbrowserError("COMPONENT_EXISTS"))
        
        # Get the component constructor
        Ctor = Components[name]
        if !Ctor then return(cloudbrowserError("NO_COMPONENT", "-#{name}"))

        rpcMethod = (method, args) =>
            browser.emit 'ComponentMethod',
                target : target
                method : method
                args   : args
                
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
        @memberof Browser
        @instance
        @return {AppConfig}
    ###
    getAppConfig : () ->
        {bserver, cbCtx, userCtx} = _pvts[@_idx]
        {server, mountPoint} = bserver
        AppConfig = require("./application_config")

        return new AppConfig
            cbCtx   : cbCtx
            userCtx : userCtx
            app     : server.applications.find(mountPoint)
    ###*
        Closes the  browser.
        @method close
        @memberof Browser
        @instance
        @param {errorCallback} callback
    ###
    close : (callback) ->
        {bserver, userCtx} = _pvts[@_idx]
        app = bserver.server.applications.find(bserver.mountPoint)

        if userCtx.getNameSpace() is "public"
            app.browsers.close(bserver)
        else
            appInstance = bserver.getAppInstance()
            if appInstance
                appInstance.removeBrowser(bserver, userCtx.toJson(), callback)
            else
                app.browsers.close(bserver, userCtx.toJson(), callback)

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
        when the user identity can not be established through authentication. 
        @method getResetEmail
        @param {emailCallback} callback
        @memberof Browser
        @instance
    ###
    getResetEmail : (callback) ->
        {bserver} = _pvts[@_idx]
        {mongoInterface} = bserver.server

        Async.waterfall [
            (next)->
                bserver.getSessions((sessionIDs) -> next(null, sessionIDs[0]))
            (sessionID, next) ->
                mongoInterface.getSession(sessionID, next)
            (session, next) ->
                next(null, session.resetuser)
        ], callback

    ###*
        Gets the user that created the instance.
        @method getCreator
        @memberof Browser
        @instance
        @return {cloudbrowser.app.User}
    ###
    getCreator : () ->
        {bserver, cbCtx} = _pvts[@_idx]
        {User} = cbCtx.app
        if bserver.creator
            {email, ns} = bserver.creator
            return new User(email, ns)

    ###*
        Registers a listener for an event on the  browser instance.
        @method addEventListener
        @memberof Browser
        @instance
        @param {String} event
        @param {errorCallback} callback 
    ###
    addEventListener : (event, callback) ->
        {bserver} = _pvts[@_idx]
        {mountPoint, id} = bserver

        @isAssocWithCurrentUser (err, isAssoc) ->
            if err then callback(err)
            else if not isAssoc then callback(cloudbrowserError("PERM_DENIED"))
            else bserver.on(event, callback)

    ###*
        Checks if the current user has some permissions
        associated with this browser
        @method isAssocWithCurrentUser
        @memberof Browser
        @instance
        @param {booleanCallback} callback 
    ###
    isAssocWithCurrentUser : (callback) ->
        {bserver, userCtx, cbCtx} = _pvts[@_idx]
        {permissionManager} = bserver.server
        {mountPoint, id}    = bserver

        permissionManager.findBrowserPermRec
            user       : userCtx.toJson()
            mountPoint : mountPoint
            browserID  : id
            callback   : (err, browserRec) ->
                if err then callback(err)
                else if not browserRec then callback(null, false)
                else callback(null, true)
    ###*
        Gets all users that have the permission only to read and
        write to the instance.
        @method getReaderWriters
        @memberof Browser
        @instance
        @param {userListCallback} callback
    ###
    getReaderWriters : (callback) ->
        {bserver, cbCtx} = _pvts[@_idx]
        {mountPoint, id} = bserver
        {User} = cbCtx.app

        @isAssocWithCurrentUser (err, isAssoc) ->
            if err then callback(err)
            else if not isAssoc then callback(cloudbrowserError("PERM_DENIED"))
            else
                rwRecs = bserver.getUsersInList('readwrite')
                readerWriters = []
                for rwRec in rwRecs
                    {email, ns} = rwRec.user
                    readerWriters.push(new User(email, ns))
                callback(null, readerWriters)

    ###*
        Gets the number of users that have the permission only to read and
        write to the instance. 
        There is a separate method for this as it is faster to get only the
        number of reader writers than to construct a list of them using
        getReaderWriters and then get that number.
        @method getNumReaderWriters
        @memberof Browser
        @instance
        @param {numberCallback} callback
    ###
    getNumReaderWriters : (callback) ->
        {bserver, cbCtx} = _pvts[@_idx]
        {mountPoint, id} = bserver

        @isAssocWithCurrentUser (err, isAssoc) ->
            if err then callback(err)
            else if not isAssoc then callback(cloudbrowserError("PERM_DENIED"))
            else callback(null, bserver.getUsersInList('readwrite').length)

    ###*
        Gets the number of users that own the instance.
        @method getNumOwners
        @memberof Browser
        @instance
        @param {numberCallback} callback
    ###
    getNumOwners : (callback) ->
        {bserver, cbCtx} = _pvts[@_idx]
        {mountPoint, id} = bserver

        @isAssocWithCurrentUser (err, isAssoc) ->
            if err then callback(err)
            else if not isAssoc then callback(cloudbrowserError("PERM_DENIED"))
            else callback(null, bserver.getUsersInList('own').length)

    ###*
        Gets all users that are the owners of the instance
        There is a separate method for this as it is faster to get only the
        number of owners than to construct a list of them using
        getOwners and then get that number.
        @method getOwners
        @memberof Browser
        @instance
        @param {userListCallback} callback
    ###
    getOwners : (callback) ->
        {bserver, cbCtx} = _pvts[@_idx]
        {mountPoint, id} = bserver
        {User} = cbCtx.app

        @isAssocWithCurrentUser (err, isAssoc) ->
            if err then callback(err)
            else if not isAssoc then callback(cloudbrowserError("PERM_DENIED"))
            else
                # Get the owners of this bserver
                owners = bserver.getUsersInList('own')
                users = []
                for owner in owners
                    {email, ns} = owner.user
                    users.push(new User(email, ns))
                callback(null, users)

    ###*
        Checks if the user is a reader-writer of the instance.
        @method isReaderWriter
        @memberof Browser
        @instance
        @param {cloudbrowser.app.User} user
        @param {booleanCallback} callback
    ###
    isReaderWriter : (user, callback) ->
        {bserver, cbCtx} = _pvts[@_idx]
        {mountPoint, id} = bserver

        if not user instanceof cbCtx.app.User
            callback(cloudbrowserError('PARAM_MISSING', "-user"))
        else if typeof callback isnt "function"
            callback(cloudbrowserError('PARAM_MISSING', "-callback"))

        @isAssocWithCurrentUser (err, isAssoc) ->
            if err then callback(err)
            else if not isAssoc then callback(cloudbrowserError("PERM_DENIED"))
            else
                user = user.toJson()
                # If the user is a reader-writer and not an owner, return true
                if bserver.findUserInList(user, 'readwrite')
                    callback(null, true)
                else
                    callback(null, false)

    ###*
        Checks if the user is an owner of the instance
        @method isOwner
        @memberof Browser
        @instance
        @param {cloudbrowser.app.User} user
        @param {booleanCallback} callback
    ###
    isOwner : (user, callback) ->
        {bserver, cbCtx} = _pvts[@_idx]
        {mountPoint, id} = bserver

        if not user instanceof cbCtx.app.User
            callback(cloudbrowserError('PARAM_MISSING', "-user"))
        else if typeof callback isnt "function"
            callback(cloudbrowserError('PARAM_MISSING', "-callback"))

        @isAssocWithCurrentUser (err, isAssoc) ->
            if err then callback(err)
            else if not isAssoc then callback(cloudbrowserError("PERM_DENIED"))
            else
                if bserver.findUserInList(user.toJson(), 'own')
                    callback(null, true)
                else
                    callback(null ,false)

    ###*
        Checks if the user has permissions to perform a set of actions
        on the instance.
        @method checkPermissions
        @memberof Browser
        @instance
        @param {Object} permTypes The values of these properties must be set to
        true to check for the corresponding permission.
        @property [boolean] own
        @property [boolean] readwrite
        @property [boolean] readonly
        @param {booleanCallback} callback
    ###
    checkPermissions : (permTypes, callback) ->
        {bserver, userCtx, cbCtx} = _pvts[@_idx]
        {permissionManager} = bserver.server
        {mountPoint, id}    = bserver

        permissionManager.checkPermissions
            user        : userCtx.toJson()
            mountPoint  : mountPoint
            browserID   : id
            permissions : permTypes
            callback    : callback
    ###*
        Grants the user a set of permissions on the instance.
        @method grantPermissions
        @memberof Browser
        @instance
        @param {Object} permTypes The values of these properties must be set to
        true to check for the corresponding permission.
        @param {boolean} [options.own]
        @param {boolean} [options.readwrite]
        @param {boolean} [options.readonly]
        @param {cloudbrowser.app.User} user 
        @param {errorCallback} callback 
    ###
    addReaderWriter : (user, callback) ->
        @_grantPermissions({readwrite : true}, user, callback)

    addOwner : (user, callback) ->
        @_grantPermissions({own : true}, user, callback)

    addReader : (user, callback) ->
        @_grantPermissions({readonly : true}, user, callback)

    _grantPermissions : (permissions, user, callback) ->
        {bserver} = _pvts[@_idx]
        {mountPoint, id}    = bserver
        {permissionManager} = bserver.server

        Async.waterfall [
            (next) =>
                @checkPermissions({own:true}, next)
            (hasPermission, next) ->
                if not hasPermission then next(cloudbrowserError("PERM_DENIED"))
                # Add the user -> bserver lookup reference
                else permissionManager.addBrowserPermRec
                    user        : user.toJson()
                    mountPoint  : mountPoint
                    browserID   : id
                    permissions : permissions
                    callback    : next
            (browserRec, next) ->
                # Add the bserver -> user lookup reference
                bserver.addUserToLists(user.toJson(), permissions,
                (err) -> next(err))
        ], callback
            
    ###*
        Renames the instance.
        @method rename
        @memberof Browser
        @instance
        @param {String} newName
        @fires Browser#rename
    ###
    rename : (newName, callback) ->
        if typeof newName isnt "string"
            callback?(cloudbrowserError("PARAM_MISSING", "-name"))
            return
        {bserver} = _pvts[@_idx]
        @checkPermissions {own:true}, (err, hasPermission) ->
            if err then callback?(err)
            else if not hasPermission
                callback?(cloudbrowserError("PERM_DENIED"))
            else
                bserver.name = newName
                bserver.emit('rename', newName)
                callback?(null)

    getAppInstanceConfig : () ->
        {bserver, cbCtx, userCtx} = _pvts[@_idx]
        {mountPoint, server} = bserver

        # TODO : Permission check
        AppInstance = require('./app_instance')
        return new AppInstance
            cbCtx       : cbCtx
            userCtx     : userCtx
            appInstance : bserver.getAppInstance()

    getLocalState : (property) ->
        {bserver} = _pvts[@_idx]
        # TODO : Permission check
        return bserver.getLocalState(property)

module.exports = Browser
