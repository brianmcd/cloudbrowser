Components = require('../server/components')
Async      = require('async')
cloudbrowserError = require('../shared/cloudbrowser_error')

###*
    Browser Shared event
    @event cloudbrowser.app.VirtualBrowser#shared
###
###*
    Browser Renamed event
    @event cloudbrowser.app.VirtualBrowser#renamed
    @type {String}
###
###*
    API for virtual browsers (constructed internally).
    @class cloudbrowser.app.VirtualBrowser
    @param {Object} options 
    @property [BrowserServer] bserver The virtual browser.
    @property [User]          userCtx The current user.
    @property [Cloudbrowser]  cbCtx   The cloudbrowser API object.
    @fires cloudbrowser.app.VirtualBrowser#shared
    @fires cloudbrowser.app.VirtualBrowser#renamed
###
class VirtualBrowser

    # Private Properties inside class closure
    _pvts = []

    constructor : (options) ->
        # Defining @_idx as a read-only property
        Object.defineProperty this, "_idx",
            value : _pvts.length

        {bserver, cbCtx, userCtx} = options

        if bserver.creator then creator = new cbCtx.app.User(
            bserver.creator.email,
            bserver.creator.ns)

        browserInfo =
            bserver : bserver
            userCtx : userCtx
            cbCtx   : cbCtx

        if creator then browserInfo.creator = creator

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
        @memberOf cloudbrowser.app.VirtualBrowser
    ###
    getID : () ->
        return _pvts[@_idx].bserver.id

    ###*
        Gets the date of creation of the instance.
        @method getDateCreated
        @return {Date}
        @instance
        @memberOf cloudbrowser.app.VirtualBrowser
    ###
    getDateCreated : () ->
        return _pvts[@_idx].bserver.dateCreated

    ###*
        Gets the name of the instance.
        @method getName
        @return {String}
        @instance
        @memberOf cloudbrowser.app.VirtualBrowser
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
        @memberof cloudbrowser.app.VirtualBrowser
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
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @return {cloudbrowser.app.AppConfig}
    ###
    getAppConfig : () ->
        AppConfig = require("./application_config")

        return new AppConfig
            server     : _pvts[@_idx].bserver.server
            cbCtx      : _pvts[@_idx].cbCtx
            userCtx    : _pvts[@_idx].userCtx
            mountPoint : _pvts[@_idx].bserver.mountPoint

    ###*
        Closes the virtual browser.
        @method close
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {errorCallback} callback
    ###
    close : (callback) ->
        {bserver, userCtx} = _pvts[@_idx]
        app = bserver.server.applications.find(bserver.mountPoint)

        if userCtx.getNameSpace() is "public" then app.browsers.close(bserver)
        else app.browsers.close(bserver, userCtx.toJson(), callback)

    ###*
        Redirects all clients that are connected to the current
        instance to the given URL.
        @method redirect
        @param {String} url
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
    ###
    redirect : (url) ->
        _pvts[@_idx].bserver.redirect(url)

    ###*
        Gets the email ID that is stored in the session
        when the user identity can not be established through authentication. 
        @method getResetEmail
        @param {emailCallback} callback
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
    ###
    getResetEmail : (callback) ->
        {bserver} = _pvts[@_idx]
        {mongoInterface} = bserver.server

        Async.waterfall [
            (next)->
                bserver.getSessions (sessionIDs) ->
                    next(null, sessionIDs[0])
            (sessionID, next) ->
                mongoInterface.getSession(sessionID, next)
            (session, next) ->
                next(null, session.resetuser)
        ], callback

    ###*
        Gets the user that created the instance.
        @method getCreator
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @return {cloudbrowser.app.User}
    ###
    getCreator : () ->
        return _pvts[@_idx].creator

    ###*
        Registers a listener for an event on the virtual browser instance.
        @method addEventListener
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {String} event
        @param {errorCallback} callback 
    ###
    addEventListener : (event, callback) ->
        {bserver} = _pvts[@_idx]
        {mountPoint, id} = bserver

        @isAssocWithCurrentUser (err) ->
            if err then callback(err)
            else switch(event)
                when "shared"
                    bserver.on(event, (user, list) -> callback(event))
                when "renamed"
                    bserver.on(event, (name) -> callback(name, event))

    ###*
        Checks if the current user has some permissions associated with this
        browser (readwrite, readonly, own, remove)
        @method isAssocWithCurrentUser
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {errorCallback} callback 
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
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {userListCallback} callback
    ###
    getReaderWriters : (callback) ->
        {bserver, cbCtx} = _pvts[@_idx]
        {mountPoint, id} = bserver
        {User} = cbCtx.app

        @isAssocWithCurrentUser (err) ->
            if err then callback(err)
            else
                # Get the readers-writers of this bserver
                rwRecs = bserver.getUsersInList('readwrite')
                readerWriters = []
                for rwRec in rwRecs
                    # If the reader-writer is not an owner then add to list
                    if not bserver.findUserInList(rwRec.user, 'own')
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
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {numberCallback} callback
    ###
    getNumReaderWriters : (callback) ->
        {bserver, cbCtx} = _pvts[@_idx]
        {mountPoint, id} = bserver

        @isAssocWithCurrentUser (err) ->
            if err then callback(err)
            else
            # Get the number of readers-writers of this bserver
                rwRecs = bserver.getUsersInList('readwrite')
                numRWers = rwRecs.length
                for rwRec in rwRecs
                    # If the reader-writer is also an owner
                    # reduce the number by one
                    if bserver.findUserInList(rwRec.user, 'own')
                        numRWers--
                callback(null, numRWers)

    ###*
        Gets the number of users that own the instance.
        @method getNumOwners
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {numberCallback} callback
    ###
    getNumOwners : (callback) ->
        {bserver, cbCtx} = _pvts[@_idx]
        {mountPoint, id} = bserver

        @isAssocWithCurrentUser (err) ->
            if err then callback(err)
            else
                ownerRecs = bserver.getUsersInList('own')
                # Return the number of owners of this bserver
                callback(null, ownerRecs.length)

    ###*
        Gets all users that are the owners of the instance
        There is a separate method for this as it is faster to get only the
        number of owners than to construct a list of them using
        getOwners and then get that number.
        @method getOwners
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {userListCallback} callback
    ###
    getOwners : (callback) ->
        {bserver, cbCtx} = _pvts[@_idx]
        {mountPoint, id} = bserver
        {User} = cbCtx.app

        @isAssocWithCurrentUser (err) ->
            if err then callback(err)
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
        @memberof cloudbrowser.app.VirtualBrowser
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

        @isAssocWithCurrentUser (err) ->
            if err then callback(err)
            else
                user = user.toJson()
                # If the user is a reader-writer and not an owner, return true
                if bserver.findUserInList(user, 'readwrite') and
                not bserver.findUserInList(user, 'own')
                    callback(null, true)
                else callback(null, false)

    ###*
        Checks if the user is an owner of the instance
        @method isOwner
        @memberof cloudbrowser.app.VirtualBrowser
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

        @isAssocWithCurrentUser (err) ->
            if err then callback(err)
            else
                # If the user is an owner then return true
                if bserver.findUserInList(user.toJson(), 'own')
                    callback(null, true)
                else callback(null ,false)

    ###*
        Checks if the user has permissions to perform a set of actions
        on the instance.
        @method checkPermissions
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {Object} permTypes The values of these properties must be set to
        true to check for the corresponding permission.
        @property [boolean] own
        @property [boolean] remove
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
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {Object} permTypes The values of these properties must be set to
        true to check for the corresponding permission.
        @property [boolean] own
        @property [boolean] remove
        @property [boolean] readwrite
        @property [boolean] readonly
        @param {cloudbrowser.app.User} user 
        @param {errorCallback} callback 
    ###
    grantPermissions : (permissions, user, callback) ->
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
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {String} newName
        @fires cloudbrowser.app.VirtualBrowser#renamed
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
                bserver.emit('renamed', newName)
                callback?(null)

module.exports = VirtualBrowser
