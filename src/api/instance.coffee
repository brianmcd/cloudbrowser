User = require('./user')
class Instance
    # Creates an instance of Instance.
    # @param {BrowserServer} browser The corresponding browser object.
    # @param {User}          user    The user that is going to communicate with the instance.
    ###*
        @class Instance
        @classdesc CloudBrowser application instances a.k.a. virtual browsers.   
    ###
    constructor : (browser, userContext) ->
        application = browser.server.applicationManager.find(browser.mountPoint)
        permissionManager = browser.server.permissionManager
        if browser.creator?
            creator = new User(browser.creator.email, browser.creator.ns)

        ###*
            @member {Number} id
            @description The (hash) ID of the instance.    
            @memberOf Instance
            @instance
        ###
        @id = browser.id
        ###*
            @description The name of the instance.
            @member {String} name    
            @memberOf Instance
            @instance
        ###
        @name = browser.name
        ###*
            @description The date of creation of the instance.
            @member {Date} dateCreated    
            @memberOf Instance
            @instance
        ###
        @dateCreated = browser.dateCreated

        ###*
            Gets the user that created the instance.
            @method getCreator
            @memberof Instance
            @instance
            @return {User}
        ###
        @getCreator = () ->
            return creator

        ###*
            Closes the instance.
            @method close
            @memberof Instance
            @instance
            @param {errorCallback} callback
        ###
        @close = (callback) ->
            application.browsers.close(browser, userContext.toJson(), callback)

        ###*
            Registers a listener on the instance for an event. The system supported events are "Shared" and "Renamed".
            @method addEventListener
            @memberof Instance
            @instance
            @param {String}   event
            @param {errorCallback} callback 
        ###
        @addEventListener = (event, callback) ->
            permissionManager.findBrowserPermRec userContext.toJson(), browser.mountPoint, browser.id, (browserRec) ->
                if browserRec?
                    if event is "Shared"
                        browser.on event, (user, list) ->
                            callback(null)
                    else if event is "Renamed"
                        browser.on event, (name) ->
                            callback(null, name)
                else callback(new Error("You do not have the permission to perform the requested action"))

        # @method #emitEvent(event, args...)
        #   Emits an event on the instance
        #   @param [String]    event   The event to be emitted.
        #   @param [Arguments] args... The arguments to be passed to the event handler. Multiple arguments are permitted.
        #
        # @emitEvent = (event, args...) ->
        #   Permission Check Required
        #   browser.emit(event, args)

        ###*
            Gets all users that have the permission only to read and write to the instance.
            @method getReaderWriters
            @memberof Instance
            @instance
            @param {userListCallback} callback
        ###
        @getReaderWriters = (callback) ->
            permissionManager.findBrowserPermRec userContext.toJson(), browser.mountPoint, browser.id, (browserRec) ->
                if browserRec?
                    readerwriterRecs = browser.getUsersInList('readwrite')
                    users = []
                    for readerwriterRec in readerwriterRecs
                        if not browser.findUserInList(readerwriterRec.user, 'own')
                            users.push(new User(readerwriterRec.user.email, readerwriterRec.user.ns))
                    callback(users)
                else callback(null)

        ###*
            Gets the number of users that have the permission only to read and write to the instance.
            @method getNumReaderWriters
            @memberof Instance
            @instance
            @param {numberCallback} callback
        ###
        @getNumReaderWriters = (callback) ->
            permissionManager.findBrowserPermRec userContext.toJson(), browser.mountPoint, browser.id, (browserRec) ->
                if browserRec?
                    readerwriterRecs = browser.getUsersInList('readwrite')
                    numReadWriters = readerwriterRecs.length
                    for readerwriterRec in readerwriterRecs
                        if browser.findUserInList(readerwriterRec.user, 'own')
                            numReadWriters--
                    callback(numReadWriters)
                else callback(null)

        ###*
            Gets the number of users that own the instance.
            @method getNumOwners
            @memberof Instance
            @instance
            @param {numberCallback} callback
        ###
        @getNumOwners = (callback) ->
            permissionManager.findBrowserPermRec userContext.toJson(), browser.mountPoint, browser.id, (browserRec) ->
                if browserRec?
                    ownerRecs = browser.getUsersInList('own')
                    callback(ownerRecs.length)
                else callback(null)

        ###*
            Gets all users that are the owners of the instance
            @method getOwners
            @memberof Instance
            @instance
            @param {userListCallback} callback
        ###
        @getOwners = (callback) ->
            permissionManager.findBrowserPermRec userContext.toJson(), browser.mountPoint, browser.id, (browserRec) ->
                if browserRec?
                    ownerRecs = browser.getUsersInList('own')
                    users = []
                    for ownerRec in ownerRecs
                        users.push(new User(ownerRec.user.email, ownerRec.user.ns))
                    callback(users)
                else callback(null)

        ###*
            Checks if the user is a reader-writer of the instance.
            @method isReaderWriter
            @memberof Instance
            @instance
            @param {User} user
            @param {booleanCallback} callback
        ###
        @isReaderWriter = (user, callback) ->
            permissionManager.findBrowserPermRec userContext.toJson(), browser.mountPoint, browser.id, (browserRec) ->
                if browserRec?
                    if browser.findUserInList(user.toJson(), 'readwrite') and
                    not browser.findUserInList(user.toJson(), 'own')
                        callback(true)
                    else callback(false)
                else callback(null)

        ###*
            Checks if the user is an owner of the instance
            @method isOwner
            @memberof Instance
            @instance
            @param {User} user
            @param {booleanCallback} callback
        ###
        @isOwner = (user, callback) ->
            permissionManager.findBrowserPermRec userContext.toJson(), browser.mountPoint, browser.id, (browserRec) ->
                if browserRec?
                    if browser.findUserInList(user.toJson(), 'own')
                        callback(true)
                    else callback(false)
                else  callback(null)

        ###*
            Checks if the user has permissions to perform a set of actions on the instance.
            @method checkPermissions
            @memberof Instance
            @instance
            @param {Object} permTypes Permissible members are 'own', 'remove', 'readwrite', 'readonly'. The values of these properties must be set to true to check for the corresponding permission.
            @param {booleanCallback} callback
        ###
        @checkPermissions = (permTypes, callback) ->
            permissionManager.findBrowserPermRec userContext.toJson(), browser.mountPoint, browser.id, (browserRec) ->
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
            @memberof Instance
            @instance
            @param {Object} permTypes Permissible members are 'own', 'remove', 'readwrite', 'readonly'. The values of these properties must be set to true to check for the corresponding permission.
            @param {User} user 
            @param {errorCallback} callback 
        ###
        @grantPermissions = (permissions, user, callback) ->
            @checkPermissions {own:true}, (hasPermission) ->
                if hasPermission
                    user = user.toJson()
                    permissionManager.findAppPermRec user, browser.mountPoint, (appRec) ->
                        if appRec?
                            permissionManager.addBrowserPermRec user, browser.mountPoint,
                            browser.id, permissions, (browserRec) ->
                                browser.addUserToLists user, permissions, () ->
                                    callback(null)
                        else
                            # Move addPermRec to permissionManager
                            browser.server.httpServer.addPermRec user, browser.mountPoint, () ->
                                permissionManager.addBrowserPermRec user, browser.mountPoint,
                                browser.id, permissions, (browserRec) ->
                                    browser.addUserToLists user, permissions, () ->
                                        callback(null)
                else callback(new Error("You do not have the permission to perform the requested action"))
        
        ###*
            Renames the instance and emits an event "Renamed" that can be listened for by registering a listener on the instance.
            @method rename
            @memberof Instance
            @instance
            @param {String} newName
        ###
        @rename = (newName) ->
            @checkPermissions {own:true}, (hasPermission) ->
                if hasPermission
                    @name = newName
                    browser.name = newName
                    browser.emit('Renamed', newName)

        ###*
            @description The owners of the instance.
            @member {Array<User>} owners
            @memberOf Instance
            @instance
        ###
        @getOwners (owners) =>
            @owners = owners
        ###*
            @description The users that can read and write to the instance.
            @member {Array<User>} collaborators
            @memberOf Instance
            @instance
        ###
        @getReaderWriters (collaborators) =>
            @collaborators = collaborators

module.exports = Instance
