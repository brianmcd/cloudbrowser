Async   = require('async')
lodash = require('lodash')
Browser = require('./browser')
User    = require('../server/user')
cloudbrowserError = require('../shared/cloudbrowser_error')

# Permission checks are included wherever possible and a note is made if
# missing. Details like name, id, url etc. are available to everybody.

###*
    The application instance has been shared with another user
    @event AppInstance#share
###
###*
    The current application instance has been renamed
    @event AppInstance#rename
    @type {String}
###
###*
    API for application instance (internal class).
    @class AppInstance
    @param {Object}         options 
    @param {User}           options.userCtx     The current user.
    @param {AppInstance}    options.appInstance The application instance.
    @param {Cloudbrowser}   options.cbCtx       The cloudbrowser API object.
    @fires AppInstance#share
    @fires AppInstance#rename
###
class AppInstance

    constructor : (options) ->
        {cbServer, appInstance, cbCtx, userCtx, appConfig} = options

        if not cbServer? or not appConfig?
            console.log "appInstance missing elements"
            err = new Error()
            console.log err.stack
        

        ###*
            Gets the ID of the application state.
            @method getID
            @return {String}
            @instance
            @memberOf AppInstance
        ###
        @getID = () ->
            return appInstance.id

        ###*
            Gets the worker id of the application state.
            @method getID
            @return {String}
            @instance
            @memberOf AppInstance
        ###
        @getWorkerID = () ->
            return appInstance.workerId

        ###*
            Gets the name of the application state.
            @method getName
            @return {String}
            @instance
            @memberOf AppInstance
        ###
        @getName = () ->
            # This name thing is actually a number
            name = appInstance.name
            return name

        ###*
            Creates a browser associated with the current application instance.
            @method createBrowser
            @param {browserCallback} callback
            @instance
            @memberOf AppInstance
        ###
        @createBrowser = (callback) ->
            # Permission checking is done inside call to createBrowser
            # in the application instance and in the browser manager
            Async.waterfall [
                (next) ->
                    appInstance.createBrowser(userCtx, next)
                (bserver, next) =>
                    next(null, new Browser({
                        browser : bserver
                        userCtx : userCtx
                        cbCtx   : cbCtx
                        cbServer : cbServer
                        appInstanceConfig : this
                        appConfig : appConfig
                    }))
            ], callback

        ###*
            Gets the date of creation of the application instance.
            @method getDateCreated
            @return {Date}
            @instance
            @memberOf AppInstance
        ###
        @getDateCreated = () ->
            return appInstance.dateCreated

        ###*
            Closes the appInstance.
            @method close
            @param {errorCallback} callback
            @instance
            @memberof AppInstance
        ###
        @close = (callback) ->
            appInstance.close(userCtx, callback)
            return

        ###*
            Gets the owner of the application instance.
            @method getOwner
            @instance
            @memberof AppInstance
        ###
        @getOwner = () ->
            # No permission check done as users may need to know
            # the owner of an app instance when they are associated
            # with a browser of the app instance but not with the 
            # app instance itself
            return appInstance.owner.getEmail()

        ###*
            Registers a listener for an event on the appInstance.
            @method addEventListener
            @param {String} event
            @param {appInstanceEventCallback} callback 
            @instance
            @memberof AppInstance
        ###
        @addEventListener = (eventName, callback) ->
            if typeof callback isnt "function" then return

            validEvents = ["rename", "share", "addBrowser", "removeBrowser", "shareBrowser"]
            if typeof eventName isnt "string" or validEvents.indexOf(eventName) is -1
                return

            appInstance.getUserPrevilege(userCtx, (err, previlege)=>
                return callback(err) if err?
                # if you are not associated with the appInstance, do nothing
                return if not previlege
                console.log "APIAppInstance : addEvent #{eventName} to appInstance #{appInstance.id}"
                listener = null
                switch(eventName)
                    when 'share'
                        listener = (user)->
                            callback(user.getEmail())
                    when 'rename','removeBrowser'
                        listener = callback
                    else
                        listener = (browser, userObj)=>
                            options =
                                cbServer : cbServer
                                cbCtx   : cbCtx
                                userCtx : userCtx
                                appInstanceConfig : this
                                appConfig : appConfig
                                browser : browser
                            callback(new Browser(options), userObj)
                cbCtx.addEventListener(appInstance, eventName, listener)    
            )
            return



        ###*
            Checks if the current user has some permissions associated with the 
            current appInstance (readwrite, own)
            @method isAssocWithCurrentUser
            @return {Bool}
            @instance
            @memberof AppInstance
        ###
        @isAssocWithCurrentUser = () ->
            if @isOwner(userCtx.getEmail()) or @isReaderWriter(userCtx.getEmail())
                return true
            return false


        ###*
            Gets all users that have the permission to read and
            write to the application instance.
            @method getReaderWriters
            @return {Bool}
            @instance
            @memberof AppInstance
        ###
        @getReaderWriters = () ->
            users = []
            if @isAssocWithCurrentUser()
                users.push(rw.getEmail()) for rw in appInstance.readerwriters
            return users

        ###*
            Checks if the user is a reader-writer of the instance.
            @method isReaderWriter
            @param {String} emailID
            @return {Bool} 
            @instance
            @memberof AppInstance
        ###
        @isReaderWriter = (emailID) ->
            if typeof emailID isnt "string" then return

            for i in appInstance.readerwriters
                if i.getEmail() is emailID
                    return true
            return false


        ###*
            Checks if the user is the owner of the application instance
            @method isOwner
            @param {String} user
            @return {Bool} 
            @instance
            @memberof AppInstance
        ###
        @isOwner = (user) ->
            if typeof user isnt "string" then return

            return user is appInstance.owner.getEmail()
            

        ###*
            Grants the user readwrite permissions on the application instance.
            @method addReaderWriter
            @param {String} emailID 
            @param {errorCallback} callback 
            @instance
            @memberof AppInstance
        ###
        @addReaderWriter = (emailID, callback) ->
            permissionManager = cbServer.permissionManager

            if typeof emailID isnt "string"
                return callback?(cloudbrowserError("PARAM_INVALID", "- emailID"))

            user = new User(emailID)

            Async.waterfall [
                (next) =>
                    if appInstance.owner.getEmail() isnt userCtx.getEmail()
                        next(cloudbrowserError("PERM_DENIED"))
                    else if appInstance.owner.getEmail() is user.getEmail()
                        next(cloudbrowserError("IS_OWNER"))
                    else permissionManager.addAppInstancePermRec
                        user          : user
                        mountPoint    : appConfig.getMountPoint()
                        permission    : 'readwrite'
                        appInstanceID : appInstance.id
                        callback      : (err) -> next(err)
                (next) ->
                    appInstance.addReaderWriter(user, next)
            ], (err, next) ->
                callback(err)
                

        ###*
            Get the application instance JavaScript object that can be used
            by the application and that is serialized and stored in the database.
            This is only called when the appInstance is a local object.
            @method getObj
            @return {Object} Custom object, the details of which are known only
            to the application code itself
            @instance
            @memberof AppInstance
        ###
        @getObj = () ->
            # if appInstance.isOwner(userCtx) or appInstance.isReaderWriter(userCtx)
            return appInstance.getObj()

        ###*
            Gets the url of the application instance.
            @method getURL
            @return {String}
            @instance
            @memberOf AppInstance
        ###
        @getURL = () ->
            appURL    = appConfig.getUrl()
            # TODO should not hard code here, should not call method from appInstance either
            return "#{appURL}/a/#{@getID()}"

        @getAllBrowsers = (callback) ->
            appInstance.getAllBrowsers((err, browsers)=>
                return callback(err) if err?
                result=[]
                options = {
                    userCtx : userCtx
                    cbCtx   : cbCtx
                    cbServer : cbServer
                    appInstanceConfig : this
                    appConfig : appConfig
                }
                options.appInstance = null
                options.appInstanceConfig = this
                for k, browser of browsers
                    newOption = lodash.merge({}, options)
                    newOption.browser = browser
                    result.push(new Browser(newOption))                
                callback null, result
            )

        @getUsers = (callback) ->
            appInstance.getUsers((err, users)->
                result = {}
                for k, v of users
                    if k is 'owners'
                        result.owner = v[0].getEmail()
                    if lodash.isArray(v)
                        result[k]=lodash.map(v, (user)->
                            return user.getEmail()
                        )
                callback(null, result)
            )

        @getEventBus = ()->
            return appInstance._eventbus


module.exports = AppInstance
