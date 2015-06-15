Async      = require('async')
lodash = require('lodash')

Components = require('../server/components')
User       = require('../server/user')
cloudbrowserError = require('../shared/cloudbrowser_error')
{areArgsValid} = require('./utils')
routes = require('../server/application_manager/routes')

uuid = 0
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
    constructor : (options) ->
        {cbServer, browser, cbCtx, userCtx, appConfig, appInstanceConfig} = options

        if not cbServer? or not appConfig? or not appInstanceConfig?
            console.log "browser api missing elements"
            err = new Error()
            console.log err.stack
        

        ###*
            Gets the ID of the instance.
            @method getID
            @return {String}
            @instance
            @memberOf Browser
        ###
        @getID = () ->
            return browser.id

        @getWorkerID = () ->
            return browser.workerId

        ###*
            Gets the url of the instance.
            @method getURL
            @return {String}
            @instance
            @memberOf Browser
        ###
        @getURL = () ->
            browserUrl = routes.buildBrowserPath(browser.mountPoint, browser.appInstanceId, browser.id)
            return "#{cbServer.config.getHttpAddr()}#{browserUrl}"
            

        ###*
            Gets the date of creation of the instance.
            @method getDateCreated
            @return {Date}
            @instance
            @memberOf Browser
        ###
        @getDateCreated = () ->
            return browser.dateCreated

        ###*
            Gets the name of the instance.
            @method getName
            @return {String}
            @instance
            @memberOf Browser
        ###
        @getName = () ->
            return browser.name

        ###*
            Creates a new component. This is called only when the browser is a local object.
            @method createComponent
            @param {String}  name    The registered name of the component.          
            @param {DOMNode} target  The DOM node in which the component will be embedded.         
            @param {Object}  options Extra options to customize the component.          
            @return {DOMNode}
            @instance
            @memberof Browser
        ###
        @createComponent = (name, target, options) ->
            return if typeof name isnt "string" or not target or not target.__nodeID
            domBrowser  = browser.getBrowser()
            domBrowser.createComponent(name, target, options)
            return target

        ###*
            Gets the Application API object.
            @method getAppConfig
            @return {AppConfig}
            @memberof Browser
            @instance
        ###
        @getAppConfig = () ->
            mountPoint = browser.mountPoint
            AppConfig  = require("./application_config")
            app = cbServer.applicationManager.find(mountPoint)

            return new AppConfig({
                cbServer : cbServer
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
        @close = (callback) ->
            # get appInstance by direct property reference. both bserver and appInstance could be remote object
            appInstance = browser.appInstance
            appInstance.removeBrowser(browser.id, userCtx, callback)
            return
            

        ###*
            Redirects all clients that are connected to the current
            instance to the given URL.
            @method redirect
            @param {String} url
            @memberof Browser
            @instance
        ###
        @redirect = (url) ->
            browser.redirect(url)
            return

        ###*
            Gets the email ID that is stored in the session
            @method getResetEmail
            @param {emailCallback} callback
            @memberof Browser
            @instance
        ###
        @getResetEmail = (callback) ->
            sessionManager = cbServer.sessionManager
            browser.getFirstSession((err, session) ->
                return callback(err) if err
                callback(null,
                    sessionManager.findPropOnSession(session, 'resetuser'))
            )
            return

        ###*
            Gets the user that created the instance.
            @method getCreator
            @return {String}
            @instance
            @memberof Browser
        ###
        @getCreator = () ->
            return browser.creator?.getEmail()

        ###*
            Registers a listener for an event on the  browser instance.
            @method addEventListener
            @param {String} event
            @param {errorCallback} callback 
            @instance
            @memberof Browser
        ###
        @addEventListener = (eventName, callback) ->
            if typeof callback isnt "function" then return

            validEvents = ["share", "rename", "connect", "disconnect"]
            if typeof eventName isnt "string" or validEvents.indexOf(eventName) is -1
                return

            
            callbackRegistered = callback
            if @isAssocWithCurrentUser() and eventName is 'share'    
                callbackRegistered = (userInfo) ->
                    newUserInfo = {}
                    newUserInfo.role = userInfo.role
                    newUserInfo.user = User.getEmail(userInfo.user)
                    callback(newUserInfo)
                    # this is really nasty, now the browser object is stale
            cbCtx.addEventListener(browser, eventName, callbackRegistered)
            return

        ###*
            Checks if the current user has some permission
            associated with this browser
            @method isAssocWithCurrentUser
            @return {Bool}
            @instance
            @memberof Browser
        ###
        @isAssocWithCurrentUser = () ->
            appConfig = @getAppConfig()
            if not appConfig.isAuthConfigured() or
                browser.isOwner(userCtx) or
                browser.isReaderWriter(userCtx) or
                browser.isReader(userCtx) or
                appConfig.isOwner()
                    return true
            else 
                return false

        ###*
            Gets all users that have the permission only to read and
            write to the instance.
            @method getReaderWriters
            @return {Array<User>}
            @instance
            @memberof Browser
        ###
        @getReaderWriters = () ->
            # There will not be any users in case authentication has
            # not been enabled
            users = []
            if typeof browser.getReaderWriters isnt "function"
                return users
            if @isAssocWithCurrentUser()
                users.push(rw.getEmail()) for rw in browser.readwrite
            return users

        ###*
            Gets all users that have the permission only to read
            @method getReaders
            @return {Array<User>}
            @instance
            @memberof Browser
        ###
        @getReaders = () ->
            # There will not be any users in case authentication has
            # not been enabled
            users = []
            if typeof browser.getReaders isnt "function"
                return users 
            if @isAssocWithCurrentUser()
                users.push(rw.getEmail()) for rw in browser.readonly
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
        @getOwners = () ->
            # There will not be any users in case authentication has
            # not been enabled
            users = []
            if typeof browser.getOwners isnt "function"
                return users
            if @isAssocWithCurrentUser()
                users.push(rw.getEmail()) for rw in browser.own
            return users

        ###*
            Checks if the user is a reader-writer of the instance.
            @method isReaderWriter
            @param {String} user
            @return {Bool}
            @instance
            @memberof Browser
        ###
        @isReaderWriter = (emailID) ->
            # There will not be any users in case authentication has
            # not been enabled
            return if typeof browser.isReaderWriter isnt "function"

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
                if browser.isReaderWriter(userCtx) then return true
                else return false

        ###*
            Checks if the user is a reader of the instance.
            @method isReader
            @param {String} emailID
            @return {Bool}
            @memberof Browser
            @instance
        ###
        @isReader = (emailID) ->
            # There will not be any users in case authentication has
            # not been enabled
            return if typeof browser.isReader isnt "function"

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
                if browser.isReader(userCtx) then return true
                else return false

        ###*
            Checks if the user is an owner of the instance
            @method isOwner
            @param {String} user
            @return {Bool}
            @instance
            @memberof Browser
        ###
        @isOwner = () ->
            # There will not be any users in case authentication has
            # not been enabled
            return if typeof browser.isOwner isnt "function"

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
                if browser.isOwner(userCtx) then return true
                else return false
                
        # [user],[callback]
        @getUserPrevilege = ()->
            switch arguments.length
                when 1
                    user = userCtx
                    callback = arguments[0]
                when 2
                    user = arguments[0]
                    callback = arguments[1]

            return callback(null, null) if typeof browser.getUserPrevilege isnt 'function'
            browser.getUserPrevilege(user, callback)
            return


        ###*
            Adds a user as a readerwriter of the current browser
            @method addReaderWriter
            @param {String} emailID
            @param {errorCallback} callback
            @instance
            @memberof Browser
        ###
        @addReaderWriter = (emailID, callback) ->
            return if not areArgsValid [
                {item : emailID, type : "string", action : callback}
            ]
            # There will not be any users in case authentication has
            # not been enabled
            if typeof browser.addReaderWriter isnt "function"
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
        @addOwner = (emailID, callback) ->
            return if not areArgsValid [
                {item : emailID, type : "string", action : callback}
            ]
            # There will not be any users in case authentication has
            # not been enabled
            if typeof browser.addOwner isnt "function"
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
        @addReader = (emailID, callback) ->
            return if not areArgsValid [
                {item : emailID, type : "string", action : callback}
            ]
            # There will not be any users in case authentication has
            # not been enabled
            if typeof browser.addReader isnt "function"
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
        @grantPermissions = (permission, user, callback) ->
            {mountPoint, id}    = browser
            
            permissionManager = cbServer.permissionManager

            Async.waterfall([
                (next)->
                    browser.getUserPrevilege(userCtx, next)
                (result, next)->
                    if result isnt 'own'
                        next(cloudbrowserError("PERM_DENIED"))
                    else
                        permissionManager.addBrowserPermRec
                            user        : user
                            mountPoint  : mountPoint
                            browserID   : id
                            permission  : permission
                            callback    : next
                (browserRec, next)->
                    browser.addUser({
                        user : user
                        permission : permission
                        }, next)
                ],(err)->
                    callback err
            )

        ###*
            Renames the instance.
            @method rename
            @param {String} newName
            @fires Browser#rename
            @instance
            @memberof Browser
        ###
        @rename = (newName) ->
            if typeof newName isnt "string" then return
            
            if browser.isOwner(userCtx)
                browser.setName(newName)
                browser.emit('rename', newName)
            return

        ###*
            Gets the application instance associated with the current browser
            @method getAppInstanceConfig
            @return {AppInstance}
            @instance
            @memberof Browser
        ###
        @getAppInstanceConfig = () ->
            appInstance = browser.getAppInstance()
            if not appInstance then return
            if @isAssocWithCurrentUser()
                AppInstance = require('./app_instance')
                return new AppInstance
                    cbCtx       : cbCtx
                    userCtx     : userCtx
                    appInstance : appInstance
                    cbServer    : cbServer

        @getAppInstanceId = ()->
            return browser.appInstanceId

        ###*
            Gets the local state with the current browser
            @method getLocalState
            @return {Object} Custom object provided by the application in the application state file
            @instance
            @memberof Browser
        ###
        @getLocalState = (property) ->
            if @isAssocWithCurrentUser()
                return browser.getLocalState(property)

        ###*
            Gets information about the users connected to the current browser
            @method getConnectedClients
            @return {Array<{{address: String, email: String}}>}
            @instance
            @memberof Browser
        ###
        @getConnectedClients = () ->
            if @isAssocWithCurrentUser()
                return browser.getConnectedClients()

        @getUsers = (callback)->
            browser.getUsers((err, users)->
                return callback(err) if err
                result ={}
                for k, v of users
                    if lodash.isArray(v)
                        result[k]= lodash.map(v, (u)->
                            return u.getEmail()
                        )
                    else
                        result[k] = v.getEmail()
                callback null, result        
            )

        # only make sence when it is the currentBrowser
        @getLogger = ()->
            return browser._logger

        # hack : share object among angularJS instances
        @createSharedObject = (obj)->
            obj.$$hashKey="cb_#{uuid++}"
            return obj

module.exports = Browser
