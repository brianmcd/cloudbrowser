Components = require("../server/components")

# Differentiate between parent applicationa and current application
class VirtualBrowser

    # Private Properties inside class closure
    _privates = []

    # Creates an instance of VirtualBrowser.
    # @param {BrowserServer} browser The corresponding browser object.
    # @param {User}          user    The user that is going to communicate with the instance.
    ###*
        @class VirtualBrowser
        @classdesc CloudBrowser application instances a.k.a. virtual browsers.   
    ###
    constructor : (browser, userContext, cloudbrowserContext) ->
        # Defining @_index as a read-only property
        Object.defineProperty this, "_index",
            value : _privates.length

        creator = if browser.creator?
            new cloudbrowserContext.app.User(browser.creator.email, browser.creator.ns)
        else null

        # Setting private properties
        _privates.push
            browser             : browser
            creator             : creator
            userContext         : userContext
            application         : browser.server.applicationManager.find(browser.mountPoint)
            cloudbrowserContext : cloudbrowserContext

        # Public properties id, name, dateCreated, owners, collaborators
        ###*
            @member {Number} id
            @description The (hash) ID of the instance.    
            @memberOf VirtualBrowser
            @instance
        ###
        @id = browser.id
        ###*
            @description The name of the instance.
            @member {String} name    
            @memberOf VirtualBrowser
            @instance
        ###
        @name = browser.name
        ###*
            @description The date of creation of the instance.
            @member {Date} dateCreated    
            @memberOf VirtualBrowser
            @instance
        ###
        @dateCreated = browser.dateCreated

        if userContext
            ###*
                @description The owners of the instance.
                @member {Array<User>} owners
                @memberOf VirtualBrowser
                @instance
            ###
            @getOwners (owners) =>
                @owners = owners
            ###*
                @description The users that can read and write to the instance.
                @member {Array<User>} collaborators
                @memberOf VirtualBrowser
                @instance
            ###
            @getReaderWriters (collaborators) =>
                @collaborators = collaborators

    ###*
        Creates a new component
        @param {String}  name    The identifying name of the component.          
        @param {DOMNode} target  The target node at which the component must be created.         
        @param {Object}  options Any extra options needed to customize the component.          
        @return {DOMNode}
    ###
    createComponent : (name, target, options) ->
        #throw new Error("Browser has been garbage collected") if cleaned
        browser = _privates[@_index].browser.browser
        targetID = target.__nodeID
        if browser.components[targetID]
            throw new Error("Can't create 2 components on the same target.")
        Ctor = Components[name]
        if !Ctor then throw new Error("Invalid component name: #{name}")

        # Is there a way to interpose on callbacks?
        rpcMethod = (method, args) =>
            browser.emit 'ComponentMethod',
                target : target
                method : method
                args   : args

        comp = browser.components[targetID] = new Ctor(options, rpcMethod, target)
        clientComponent = [name, targetID, comp.getRemoteOptions()]
        browser.clientComponents.push(clientComponent)

        browser.emit('CreateComponent', clientComponent)
        return target

    getAppConfig : () ->
        return new _privates[@_index].cloudbrowserContext.app.AppConfig(_privates[@_index].browser, _privates[@_index].cloudbrowserContext)
    ###*
        Gets the user that created the instance.
        @method getCreator
        @memberof VirtualBrowser
        @instance
        @return {User}
    ###
    getCreator : () ->
        return _privates[@_index].creator

    ###*
        Closes the instance.
        @method close
        @memberof VirtualBrowser
        @instance
        @param {errorCallback} callback
    ###
    close : (callback) ->
        _privates[@_index].application.browsers.close(_privates[@_index].browser,
        _privates[@_index].userContext.toJson(), callback)

    ###*
        Registers a listener on the instance for an event. The system supported events are "Shared" and "Renamed".
        @method addEventListener
        @memberof VirtualBrowser
        @instance
        @param {String}   event
        @param {errorCallback} callback 
    ###
    addEventListener : (event, callback) ->
        permissionManager = _privates[@_index].browser.server.permissionManager
        permissionManager.findBrowserPermRec _privates[@_index].userContext.toJson(),
        _privates[@_index].browser.mountPoint, _privates[@_index].browser.id, (browserRec) =>
            if browserRec?
                if event is "Shared"
                    _privates[@_index].browser.on event, (user, list) ->
                        callback(null)
                else if event is "Renamed"
                    _privates[@_index].browser.on event, (name) ->
                        callback(null, name)
            else callback(new Error("You do not have the permission to perform the requested action"))

    ###*
        Gets all users that have the permission only to read and write to the instance.
        @method getReaderWriters
        @memberof VirtualBrowser
        @instance
        @param {userListCallback} callback
    ###
    getReaderWriters : (callback) ->
        user =  _privates[@_index].cloudbrowserContext.app.User
        permissionManager = _privates[@_index].browser.server.permissionManager
        permissionManager.findBrowserPermRec _privates[@_index].userContext.toJson(),
        _privates[@_index].browser.mountPoint, _privates[@_index].browser.id, (browserRec) =>
            if browserRec?
                readerwriterRecs = _privates[@_index].browser.getUsersInList('readwrite')
                users = []
                for readerwriterRec in readerwriterRecs
                    if not _privates[@_index].browser.findUserInList(readerwriterRec.user, 'own')
                        users.push(new user(readerwriterRec.user.email, readerwriterRec.user.ns))
                callback(users)
            else callback(null)

    ###*
        Gets the number of users that have the permission only to read and write to the instance.
        @method getNumReaderWriters
        @memberof VirtualBrowser
        @instance
        @param {numberCallback} callback
    ###
    getNumReaderWriters : (callback) ->
        permissionManager = _privates[@_index].browser.server.permissionManager
        permissionManager.findBrowserPermRec _privates[@_index].userContext.toJson(),
        _privates[@_index].browser.mountPoint, _privates[@_index].browser.id, (browserRec) =>
            if browserRec?
                readerwriterRecs = _privates[@_index].browser.getUsersInList('readwrite')
                numReadWriters = readerwriterRecs.length
                for readerwriterRec in readerwriterRecs
                    if _privates[@_index].browser.findUserInList(readerwriterRec.user, 'own')
                        numReadWriters--
                callback(numReadWriters)
            else callback(null)

    ###*
        Gets the number of users that own the instance.
        @method getNumOwners
        @memberof VirtualBrowser
        @instance
        @param {numberCallback} callback
    ###
    getNumOwners : (callback) ->
        permissionManager = _privates[@_index].browser.server.permissionManager
        permissionManager.findBrowserPermRec _privates[@_index].userContext.toJson(),
        _privates[@_index].browser.mountPoint, _privates[@_index].browser.id, (browserRec) =>
            if browserRec?
                ownerRecs = _privates[@_index].browser.getUsersInList('own')
                callback(ownerRecs.length)
            else callback(null)

    ###*
        Gets all users that are the owners of the instance
        @method getOwners
        @memberof VirtualBrowser
        @instance
        @param {userListCallback} callback
    ###
    getOwners : (callback) ->
        user =  _privates[@_index].cloudbrowserContext.app.User
        permissionManager = _privates[@_index].browser.server.permissionManager
        permissionManager.findBrowserPermRec _privates[@_index].userContext.toJson(),
        _privates[@_index].browser.mountPoint, _privates[@_index].browser.id, (browserRec) =>
            if browserRec?
                ownerRecs = _privates[@_index].browser.getUsersInList('own')
                users = []
                for ownerRec in ownerRecs
                    users.push(new user(ownerRec.user.email, ownerRec.user.ns))
                callback(users)
            else callback(null)

    ###*
        Checks if the user is a reader-writer of the instance.
        @method isReaderWriter
        @memberof VirtualBrowser
        @instance
        @param {User} user
        @param {booleanCallback} callback
    ###
    isReaderWriter : (user, callback) ->
        permissionManager = _privates[@_index].browser.server.permissionManager
        permissionManager.findBrowserPermRec _privates[@_index].userContext.toJson(),
        _privates[@_index].browser.mountPoint, _privates[@_index].browser.id, (browserRec) =>
            if browserRec?
                if _privates[@_index].browser.findUserInList(user.toJson(), 'readwrite') and
                not _privates[@_index].browser.findUserInList(user.toJson(), 'own')
                    callback(true)
                else callback(false)
            else callback(null)

    ###*
        Checks if the user is an owner of the instance
        @method isOwner
        @memberof VirtualBrowser
        @instance
        @param {User} user
        @param {booleanCallback} callback
    ###
    isOwner : (user, callback) ->
        permissionManager = _privates[@_index].browser.server.permissionManager
        permissionManager.findBrowserPermRec _privates[@_index].userContext.toJson(),
        _privates[@_index].browser.mountPoint, _privates[@_index].browser.id, (browserRec) =>
            if browserRec?
                if _privates[@_index].browser.findUserInList(user.toJson(), 'own')
                    callback(true)
                else callback(false)
            else  callback(null)

    ###*
        Checks if the user has permissions to perform a set of actions on the instance.
        @method checkPermissions
        @memberof VirtualBrowser
        @instance
        @param {Object} permTypes Permissible members are 'own', 'remove', 'readwrite', 'readonly'. The values of these properties must be set to true to check for the corresponding permission.
        @param {booleanCallback} callback
    ###
    checkPermissions : (permTypes, callback) ->
        permissionManager = _privates[@_index].browser.server.permissionManager
        permissionManager.findBrowserPermRec _privates[@_index].userContext.toJson(),
        _privates[@_index].browser.mountPoint, _privates[@_index].browser.id, (browserRec) =>
            if browserRec
                for type,v of permTypes
                    if not browserRec.permissions[type] or
                    typeof browserRec.permissions[type] is "undefined"
                        callback(false)
                        return
                callback(true)
            else callback(false)

    ###*
        Grants the user a set of permissions on the instance.
        @method grantPermissions
        @memberof VirtualBrowser
        @instance
        @param {Object} permTypes Permissible members are 'own', 'remove', 'readwrite', 'readonly'. The values of these properties must be set to true to check for the corresponding permission.
        @param {User} user 
        @param {errorCallback} callback 
    ###
    grantPermissions : (permissions, user, callback) ->
        permissionManager = _privates[@_index].browser.server.permissionManager
        @checkPermissions {own:true}, (hasPermission) =>
            if hasPermission
                user = user.toJson()
                permissionManager.findAppPermRec user,
                _privates[@_index].browser.mountPoint, (appRec) =>
                    if appRec?
                        permissionManager.addBrowserPermRec user,
                        _privates[@_index].browser.mountPoint,
                        _privates[@_index].browser.id, permissions, (browserRec) =>
                            _privates[@_index].browser.addUserToLists user, permissions, () ->
                                callback(null)
                    else
                        # Move addPermRec to permissionManager
                        _privates[@_index].browser.server.httpServer.addPermRec user,
                        _privates[@_index].browser.mountPoint, () =>
                            permissionManager.addBrowserPermRec user,
                            _privates[@_index].browser.mountPoint,
                            _privates[@_index].browser.id, permissions, (browserRec) =>
                                _privates[@_index].browser.addUserToLists user, permissions, () ->
                                    callback(null)
            else callback(new Error("You do not have the permission to perform the requested action"))
    
    ###*
        Renames the instance and emits an event "Renamed" that can be listened for by registering a listener on the instance.
        @method rename
        @memberof VirtualBrowser
        @instance
        @param {String} newName
    ###
    rename : (newName) ->
        @checkPermissions {own:true}, (hasPermission) =>
            if hasPermission
                @name = newName
                _privates[@_index].browser.name = newName
                _privates[@_index].browser.emit('Renamed', newName)

    ###*
        Redirects all clients connected to the current instance to the given URL.    
        @param {String} url
    ###
    redirect : (url) ->
        _privates[@_index].browser.redirect(url)

    ###*
        Gets the user's email ID that is stored in the session. 
    ###
    getResetEmail : (callback) ->
        mongoInterface = _privates[@_index].browser.server.mongoInterface
        _privates[@_index].browser.getSessions (sessionIDs) ->
            if sessionIDs.length
                mongoInterface.getSession sessionIDs[0], (session) ->
                    callback(session.resetuser)
            else callback(null)

module.exports = VirtualBrowser
