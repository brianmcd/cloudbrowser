User = require('./user')
# CloudBrowser application instances a.k.a. virtual browsers.   
#
# Instance Variables
# ------------------
# @property [Number] `id`           - The (hash) ID of the instance.    
# @property [String] `name`         - The name of the instance.   
# @property [Date]   `dateCreated`  - The date of creation of the instance.   
# @property [Array<User>] `owners`  - The owners of the instance.   
# @property [Array<User>] `collaborators` - The users that can read and write to the instance.   
#
# @method #getCreator()
#   Gets the user that created the instance.
#   @return [User] The creator of the instance.
#
# @method #close(callback)
#   Closes the instance.
#   @param [Function] callback Any error is passed as an argument
#
# @method #addEventListener(event, callback)
#   Registers a listener on the instance for an event. 
#   @param [String]   event    The event to be listened for. The system supported events are "Shared" and "Renamed".
#   @param [Function] callback The error is passed as an argument.
#
# @method #getReaderWriters()
#   Gets all users that have the permission only 
#   to read and write to the instance.
#   @return [Array<User>] List of all reader writers of the instance. Null if the creator does not have any permissions associated with the instance.
#
# @method #getOwners()
#   Gets all users that are the owners of the instance
#   @return [Array<User>] List of all owners of the instance. Null if the creator does not have any permissions associated with the instance.
#
# @method #isReaderWriter(user)
#   Checks if the user is a reader-writer of the instance.
#   @param [User] user The user to be tested.
#   @return [Bool] Indicates whether the user is a reader writer of the instance or not. Null if the creator does not have any permissions associated with the instance.
#
# @method #isOwner(user)
#   Checks if the user is an owner of the instance
#   @param [User] user The user to be tested.
#   @return [Bool] Indicates whether the user is an owner of the instance or not. Null if the creator does not have any permissions associated with the instance.
#
# @method #checkPermissions(permTypes, callback)
#   Checks if the user has permissions to perform a set of actions on the instance.
#   @param [Object]   permTypes Permissible members are 'own', 'remove', 'readwrite', 'readonly'. The values of these properties must be set to true to check for the corresponding permission.
#   @param [Function] callback  A boolean indicating whether the user has permissions or not is passed as an argument.
#
# @method #grantPermissions(permissions, user, callback)
#   Grants the user a set of permissions on the instance.
#   @param [Object]   permTypes Permissible members are 'own', 'remove', 'readwrite', 'readonly'. The values of these properties must be set to true to check for the corresponding permission.
#   @param [User]     user      The user to be granted permission to.
#   @param [Function] callback  The error is passed as an argument to the callback.
#
# @method #rename()
#   Renames the instance and emits an event "Renamed" that can be listened for by registering a listener on the instance.
class Instance
    # Creates an instance of Instance.
    # @param [BrowserServer] browser The corresponding browser object.
    # @param [User]          user    The user that is going to communicate with the instance.
    constructor : (browser, userContext) ->
        application = browser.server.applicationManager.find(browser.mountPoint)
        permissionManager = browser.server.permissionManager
        if browser.creator?
            creator = new User(browser.creator.email, browser.creator.ns)

        @id          = browser.id
        @name        = browser.name
        @dateCreated = browser.dateCreated

        @getCreator = () ->
            return creator

        @close = (callback) ->
            application.browsers.close(browser, userContext.toJson(), callback)

        @addEventListener = (event, callback) ->
            permissionManager.findBrowserPermRec userContext.toJson(), browser.mountPoint, @id, (browserRec) ->
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

        @getReaderWriters = () ->
            permissionManager.findBrowserPermRec userContext.toJson(), browser.mountPoint, @id, (browserRec) ->
                if browserRec?
                    readerwriterRecs = browser.getUsersInList('readwrite')
                    users = []
                    for readerwriterRec in readerwriterRecs
                        if not browser.findUserInList(readerwriterRec.user, 'own')
                            users.push(new User(readerwriterRec.user.email, readerwriterRec.user.ns))
                    return users
                else return null

        @getOwners = () ->
            permissionManager.findBrowserPermRec userContext.toJson(), browser.mountPoint, @id, (browserRec) ->
                if browserRec?
                    ownerRecs = browser.getUsersInList('own')
                    users = []
                    for ownerRec in ownerRecs
                        users.push(new User(ownerRec.user.email, ownerRec.user.ns))
                    return users
                else return null

        @isReaderWriter = (user) ->
            permissionManager.findBrowserPermRec userContext.toJson(), browser.mountPoint, @id, (browserRec) ->
                if browserRec?
                    if browser.findUserInList(user.toJson(), 'readwrite') and
                    not browser.findUserInList(user.toJson(), 'own')
                        return true
                    else return false
                else return null

        @isOwner = (user) ->
            permissionManager.findBrowserPermRec userContext.toJson(), browser.mountPoint, @id, (browserRec) ->
                if browserRec?
                    if browser.findUserInList(user.toJson(), 'own')
                        return true
                    else return false
                else return null

        @checkPermissions = (permTypes, callback) ->
            permissionManager.findBrowserPermRec userContext.toJson(), browser.mountPoint, @id, (browserRec) ->
                if browserRec
                    for type,v of permTypes
                        if not browserRec.permissions[type] or
                        typeof browserRec.permissions[type] is "undefined"
                            callback(false)
                            return
                    callback(true)
                else callback(false)

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
        
        @rename = (newName) ->
            @checkPermissions {own:true}, (hasPermission) ->
                if hasPermission
                    @name = newName
                    browser.name = newName
                    browser.emit('Renamed', newName)

        @owners = @getOwners()
        @collaborators = @getReaderWriters()

module.exports = Instance
