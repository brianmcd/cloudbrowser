Components = require("../server/components")

###*
    Provides access to the API for cloudbrowser application instances
    (virtual browsers).
    @class cloudbrowser.app.VirtualBrowser
    @param {BrowserServer} bserver The corresponding bserver object.
    @param {User}          userCtx The user communicating with the instance.
    @fires cloudbrowser.app.VirtualBrowser#shared
    @fires cloudbrowser.app.VirtualBrowser#renamed
###
class VirtualBrowser

    # Private Properties inside class closure
    _pvts = []

    # Creates an instance of VirtualBrowser.
    constructor : (options) ->
        # Defining @_idx as a read-only property
        Object.defineProperty this, "_idx",
            value : _pvts.length

        {bserver, cbCtx, userCtx} = options

        if bserver.creator?
            creator = new cbCtx.app.User(
                bserver.creator.email,
                bserver.creator.ns)
        else
            creator = null

        # Setting private properties
        _pvts.push
            bserver     : bserver
            creator     : creator
            userCtx     : userCtx
            cbCtx       : cbCtx

        # Public properties id, dateCreated
        # They will not change during the lifetime of the browser
        # so it's ok to freeze them
        ###*
            @member {Number} id
            @description The (hash) ID of the instance.    
            @memberOf cloudbrowser.app.VirtualBrowser
            @instance
        ###
        @id = bserver.id
        ###*
            @description The date of creation of the instance.
            @member {Date} dateCreated    
            @memberOf cloudbrowser.app.VirtualBrowser
            @instance
        ###
        @dateCreated = bserver.dateCreated

        # Freezing the prototype to protect from unauthorized changes
        # by people using the API
        Object.freeze(this.__proto__)
        Object.freeze(this)

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
        @param {DOMNode} target  The target at which the component must be created.         
        @param {Object}  options Extra options to customize the component.          
        @return {DOMNode}
        @instance
        @memberof cloudbrowser.app.VirtualBrowser
    ###
    createComponent : (name, target, options) ->
        {bserver} = _pvts[@_idx]
        browser = bserver.browser

        # bserver may have been gc'ed
        if browser?
            # Get the component constructor
            targetID = target.__nodeID
            if browser.components[targetID]
                throw new Error("Can't create 2 components on the same target.")
            Ctor = Components[name]
            if !Ctor then throw new Error("Invalid component name: #{name}")

            rpcMethod = (method, args) =>
                browser.emit 'ComponentMethod',
                    target : target
                    method : method
                    args   : args
            # Create the component
            comp = browser.components[targetID] = new Ctor(options, rpcMethod, target)
            clientComponent = [name, targetID, comp.getRemoteOptions()]
            browser.clientComponents.push(clientComponent)

            browser.emit('CreateComponent', clientComponent)
            return target

    ###*
        Gets the app configuration that created the instance.
        @method getCreator
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @return {cloudbrowser.app.User}
    ###
    getAppConfig : () ->
        AppConfig = require("./application_config")

        return new AppConfig
            server     : _pvts[@_idx].bserver.server
            cbCtx      : _pvts[@_idx].cbCtx
            userCtx    : _pvts[@_idx].userCtx
            mountPoint : _pvts[@_idx].bserver.mountPoint

    ###*
        Closes the instance.
        @method close
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {errorCallback} callback
    ###
    close : (callback) ->
        {bserver, userCtx} = _pvts[@_idx]
        app = bserver.server.applications.find(bserver.mountPoint)

        if userCtx.getNameSpace() is "public"
            app.browsers.close(bserver)
        else
            app.browsers.close(bserver, userCtx.toJson(), callback)

    ###*
        Redirects all clients connected to the current instance to the given URL.
        @method redirect
        @param {String} url
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
    ###
    redirect : (url) ->
        _pvts[@_idx].bserver.redirect(url)

    ###*
        Gets the user's email ID that is stored in the session. 
        @method getResetEmail
        @param {emailCallback} callback
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
    ###
    getResetEmail : (callback) ->
        {bserver} = _pvts[@_idx]
        {mongoInterface} = bserver.server

        bserver.getSessions (sessionIDs) ->
            if sessionIDs.length
                mongoInterface.getSession sessionIDs[0], (session) ->
                    callback(session.resetuser)
            else callback(null)

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
        Registers a listener on the instance for an event.
        The system supported events are "Shared" and "Renamed".
        @method addEventListener
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {String}   event
        @param {errorCallback} callback 
    ###
    addEventListener : (event, callback) ->
        {bserver, userCtx} = _pvts[@_idx]
        permMgr = bserver.server.permissionManager
        {mountPoint, id} = bserver

        permMgr.findBrowserPermRec userCtx.toJson(), mountPoint, id,
            (browserRec) ->
                # If the user is associated with this bserver, then
                # allow this action
                if browserRec? then switch(event)
                    when "shared"
                        bserver.on event, (user, list) ->
                            callback(null, event)
                    when "renamed"
                        bserver.on event, (name) ->
                            callback(null, name, event)
                else
                    callback(new Error("Permission Denied"))

    ###*
        Gets all users that have the permission only to read and
        write to the instance.
        @method getReaderWriters
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {userListCallback} callback
    ###
    getReaderWriters : (callback) ->
        {bserver, userCtx, cbCtx} = _pvts[@_idx]
        {User}  = cbCtx.app
        permMgr = bserver.server.permissionManager
        {mountPoint, id} = bserver

        permMgr.findBrowserPermRec userCtx.toJson(), mountPoint, id,
            (browserRec) ->
                # If the user is associated with this bserver, then
                # allow this action
                if browserRec?
                    # Get the readers-writers of this bserver
                    rwRecs = bserver.getUsersInList('readwrite')
                    rwers = []
                    for rwRec in rwRecs
                        # If the reader-writer is not also an owner
                        # add to the list
                        if not bserver.findUserInList(rwRec.user, 'own')
                            rwer = new User(rwRec.user.email, rwRec.user.ns)
                            rwers.push(rwer)
                    callback(rwers)
                else callback(null)

    ###*
        Gets the number of users that have the permission only to read and
        write to the instance.
        @method getNumReaderWriters
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {numberCallback} callback
    ###
    getNumReaderWriters : (callback) ->
        {bserver, userCtx, cbCtx} = _pvts[@_idx]
        permMgr = bserver.server.permissionManager
        {mountPoint, id} = bserver

        permMgr.findBrowserPermRec userCtx.toJson(), mountPoint, id,
            (browserRec) ->
                # If the user is associated with this bserver, then
                # allow this action
                if browserRec?
                    # Get the number of readers-writers of this bserver
                    rwRecs = bserver.getUsersInList('readwrite')
                    numRWers = rwRecs.length
                    for rwRec in rwRecs
                        # If the reader-writer is also an owner
                        # reduce the number by one
                        if bserver.findUserInList(rwRec.user, 'own')
                            numRWers--
                    callback(numRWers)
                else callback(null)

    ###*
        Gets the number of users that own the instance.
        @method getNumOwners
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {numberCallback} callback
    ###
    getNumOwners : (callback) ->
        {bserver, userCtx, cbCtx} = _pvts[@_idx]
        permMgr = bserver.server.permissionManager
        {mountPoint, id} = bserver

        permMgr.findBrowserPermRec userCtx.toJson(), mountPoint, id,
            (browserRec) ->
                # If the user is associated with this bserver, then
                # allow this action
                if browserRec?
                    ownerRecs = bserver.getUsersInList('own')
                    # Return the number of owners of this bserver
                    callback(ownerRecs.length)
                else callback(null)

    ###*
        Gets all users that are the owners of the instance
        @method getOwners
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {userListCallback} callback
    ###
    getOwners : (callback) ->
        {bserver, userCtx, cbCtx} = _pvts[@_idx]
        permMgr = bserver.server.permissionManager
        {mountPoint, id} = bserver
        {User} = cbCtx.app

        permMgr.findBrowserPermRec userCtx.toJson(), mountPoint, id,
            (browserRec) ->
                # If the user is associated with this bserver, then
                # allow this action
                if browserRec?
                    # Get the owners of this bserver
                    owners = bserver.getUsersInList('own')
                    users = []
                    for owner in owners
                        users.push(new User(owner.user.email, owner.user.ns))
                    callback(users)
                else callback(null)

    ###*
        Checks if the user is a reader-writer of the instance.
        @method isReaderWriter
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {cloudbrowser.app.User} user
        @param {booleanCallback} callback
    ###
    isReaderWriter : (user, callback) ->
        {bserver, userCtx, cbCtx} = _pvts[@_idx]
        permMgr = bserver.server.permissionManager
        {mountPoint, id} = bserver

        permMgr.findBrowserPermRec userCtx.toJson(), mountPoint, id,
            (browserRec) ->
                # If the user is associated with this bserver, then
                # allow this action
                if browserRec?
                    # If the user is a reader-writer but not an owner
                    # then return true
                    if bserver.findUserInList(user.toJson(), 'readwrite') and
                    not bserver.findUserInList(user.toJson(), 'own')
                        callback(true)
                    else callback(false)
                # What is this case for?
                else callback(null)

    ###*
        Checks if the user is an owner of the instance
        @method isOwner
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {cloudbrowser.app.User} user
        @param {booleanCallback} callback
    ###
    isOwner : (user, callback) ->
        {bserver, userCtx, cbCtx} = _pvts[@_idx]
        permMgr = bserver.server.permissionManager
        {mountPoint, id} = bserver

        permMgr.findBrowserPermRec userCtx.toJson(), mountPoint, id,
            (browserRec) ->
                # If the user is associated with this bserver, then
                # allow this action
                if browserRec?
                    # If the user is an owner then return true
                    if bserver.findUserInList(user.toJson(), 'own')
                        callback(true)
                    else callback(false)
                # What is this case for?
                else  callback(null)

    ###*
        Checks if the user has permissions to perform a set of actions
        on the instance.
        @method checkPermissions
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {Object} permTypes Permissible members are 'own', 'remove',
        'readwrite', 'readonly'. The values of these properties must be
        set to true to check for the corresponding permission.
        @param {booleanCallback} callback
    ###
    checkPermissions : (permTypes, callback) ->
        {bserver, userCtx, cbCtx} = _pvts[@_idx]
        permMgr = bserver.server.permissionManager
        {mountPoint, id} = bserver

        permMgr.findBrowserPermRec userCtx.toJson(), mountPoint, id,
            (browserRec) ->
                # If the user is associated with this bserver, then
                # allow this action
                if browserRec?
                    # Iterate through each of the permissions to be checked for
                    for type,v of permTypes
                        # If even one permission isn't true, return false
                        if not browserRec.permissions[type] or
                        typeof browserRec.permissions[type] is "undefined"
                            callback(false)
                            return
                    # If all permissions are true, return true
                    callback(true)
                else callback(false)

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
        permMgr   = bserver.server.permissionManager
        {mountPoint, id} = bserver

        addPerm = () ->
            # Add the subject(user) to object(bserver) pointer
            permMgr.addBrowserPermRec user, mountPoint, id, permissions,
                (browserRec) ->
                # Add the object(bserver) to subject(user) pointer
                    bserver.addUserToLists user, permissions, () ->
                        # Return with no errors
                        callback(null)

        # Must be the owner to grant permissions
        @checkPermissions {own:true}, (hasPermission) ->
            if hasPermission
                user = user.toJson()
                permMgr.findAppPermRec user, mountPoint,
                    (appRec) ->
                        # TODO : Must refactor this
                        if appRec? then addPerm()
                        else
                            # Move addPermRec to permMgr
                            bserver.server.httpServer.addPermRec user,
                                bserver.mountPoint, () ->
                                    addPerm()
            else callback(new Error("Permission Denied"))
    
    ###*
        Renames the instance and emits an event "Renamed" that can be listened for by registering a listener on the instance.
        @method rename
        @memberof cloudbrowser.app.VirtualBrowser
        @instance
        @param {String} newName
    ###
    rename : (newName) ->
        {bserver} = _pvts[@_idx]
        # Must be the owner to rename
        @checkPermissions {own:true}, (hasPermission) ->
            if hasPermission
                bserver.name = newName
                bserver.emit('Renamed', newName)

module.exports = VirtualBrowser
###*
    Browser Shared event
    @event cloudbrowser.app.VirtualBrowser#shared
###
###*
    Browser Renamed event
    @event cloudbrowser.app.VirtualBrowser#renamed
    @type {String}
###
