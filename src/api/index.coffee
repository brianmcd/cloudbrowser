###*
    The cloudbrowser object that is attached to the global window object
    of every browser.
    It provides the CloudBrowser API to the instance.
    @namespace cloudbrowser
###
lodash         = require('lodash')

Util           = require('./util')
ServerConfig   = require('./server_config')
User           = require('../server/user')
BrowserAPI     = require('./browser')
Authentication = require('./authentication')
cloudbrowserError = require('../shared/cloudbrowser_error')
AppConfig  = require("./application_config")
AppInstance = require('./app_instance')

class EventListenerRecord
    constructor : (entity, logger)->
        @entity = entity
        @listeners = {}
        @logger = logger

    refersTo : (entity)->
        return this.entity is entity

    addListener : (eventName, listener)->
        entity = @entity
        if not entity.addEventListener? and not entity.on?
            throw new Error("addEventListener failed: entity doesn't have method to add event listeners")
        if entity.addEventListener?
            entity.addEventListener(eventName, listener)
        else
            entity.on(eventName, listener)

        if not @listeners[eventName]?
            @listeners[eventName] = [listener]
        else
            @listeners[eventName].push(listener)

    removeEventListeners : ()->
        if @entity.removeEventListeners?
            try
                # remove eventListners should always accept event->listeners structure
                @entity.removeEventListeners(@listeners)
            catch e
                @logger("error when remove listener")
                @logger(e)
            return
        if @entity.removeListener?
            for eventName, listeners of @listeners
                for listener in listeners
                    @entity.removeListener(eventName, listener)
            return
        throw new Error("Entity doesn't have method to remove event listeners")       

class CloudBrowser

    constructor : (bserver) ->

        # Freezing the prototype to protect from unauthorized changes
        # by people using the API
        Object.freeze(this.__proto__)

        # Will not be able to attach page manager, local, shared state to
        # the cloudbrowser object.
        # TODO : Fix this dynamic attachment of properties as we must freeze
        # the object
        #Object.freeze(this)

        # To completely protect the API object we need to freeze Object.prototype
        # There are functions up on the prototype chain that we use
        # like Array.pop() Array.push() etc.
        # and these can be changed if we don't freeze Object.prototype

        # These objects are frozen in their respective constructors
        # so we don't have to worry about the fact that freeze is 
        # shallow.
        
        if bserver.creator then creator = bserver.creator
        # General user with least privileges for applications 
        # where the user identity can not be established due to
        # the absence of the authentication interface
        else creator = new User("public")

        listenerRecords = []
        logger = bserver._logger

        ###
        add EventListener,
        the event listners add here will be removed after virtualbrowser get closed
        ###
        @addEventListener = (entity, event, listener)->
            listenerRecord = null
            for i in listenerRecords
                if i.refersTo(entity)
                    listenerRecord = i
                    break
            if not listenerRecord?
                listenerRecord = new EventListenerRecord(entity, logger)
                listenerRecords.push(listenerRecord)
            listenerRecord.addListener(event, listener)
            return
        ###
        this interface makes sense because we want to remove some entity from view
        or terminate some entity, like terminate a browser.
        because application won't hold reference to any internal object, it is safe
        to expose this method to application
        ###
        @removeEventListeners = (entity)->
            removed = lodash.remove(listenerRecords, (item)->
                return item.refersTo(entity)
            )
            for i in removed
                i.removeEventListeners()
            

        ###
        close the api object, after that, the api object would be defunct
        ###
        @close = ()->
            if not listenerRecords?
                return
            
            # release all event listeners
            for i in listenerRecords
                i.removeEventListeners()
            listenerRecords = null
            return

        @util = new Util(bserver.server.config.emailerConfig)

        app = bserver.appInstance.app

        @currentAppConfig = new AppConfig({
            cbServer : bserver.server
            cbCtx   : this
            userCtx : creator
            app     : app
        })

        if app.parentApp?
            @parentAppConfig = new AppConfig({
                cbServer : bserver.server
                cbCtx   : this
                userCtx : creator
                app     : app.parentApp

            })
        

        @currentAppInstanceConfig = new AppInstance
            cbServer : bserver.server
            appInstance : bserver.appInstance
            cbCtx : this
            userCtx : creator
            appConfig : @currentAppConfig


        @currentBrowser = new BrowserAPI
            browser : bserver
            userCtx : creator
            cbCtx   : this
            cbServer : bserver.server
            appConfig : @currentAppConfig
            appInstanceConfig : @currentAppInstanceConfig

        
        # we only use Authentication object in subsidiary apps like landing page and login page.
        # this object only cares the information from the 'real' app
        if app.isAuthConfigured() or app.isAuthApp()
            realApp = app.parentApp
            if app.isStandalone()
                realApp = app

            @auth = new Authentication
                bserver : bserver
                app     : realApp
                cbCtx   : this

        @serverConfig = new ServerConfig
            cbServer : bserver.server
            userCtx : creator
            cbCtx   : this

    ###*
        The Application Namespace
        @namespace cloudbrowser.app
    ###
    app :
        Model       : require('./model')
        PageManager : require('./page_manager')

module.exports = (bserver) ->
    cloudbrowser = new CloudBrowser(bserver)
    {window} = bserver.browser
    window.cloudbrowser = cloudbrowser
    {server} = bserver

    app = bserver.server.applicationManager.find(bserver.mountPoint)
    if app.localState?
        if typeof app.localState.create is "function"
            property = if typeof app.localState.name is "string"
                           app.localState.name
                       else "local"
            localState = app.localState.create(cloudbrowser)
            if not bserver.getLocalState(property)
                bserver.setLocalState(property, localState)
            else console.log(cloudbrowserError('PROPERTY_EXISTS', "- #{property}"))

    

    # If an app needs server-side knockout, we have to monkey patch
    # some ko functions.
    if server.config.knockout
        # TODO : Fix ko
        cloudbrowser.ko = require('./ko')
        Browser = require('../server/virtual_browser/browser')
        window.run(Browser.jQScript(), "jquery-1.6.2.js")
        window.run(Browser.koScript(), "knockout-latest.debug.js")
        window.run(Browser.koPatch(), "ko-patch.js")

# TODO : Put the documentation of these callbacks somewhere else.
###*
    @callback instanceListCallback 
    @param {Error} error
    @param {Array<Browser>} browser A list of the browser config api objects.
###
###*
    @callback appListCallback 
    @param {Error} error
    @param {Array<AppConfig>} apps A list of app config api objects.
###
###*
    @callback UserListCallback 
    @param {Error} error
    @param {Array<String>} users A list of users.
###
###*
    @callback errorCallback
    @param {Error} error 
###
###*
    @callback applicationConfigEventCallback
    @param {BrowserAPI | Number} eventArg
###
###*
    @callback serverConfigEventCallback
    @param {AppConfig | String} eventArg
###
###*
    @callback booleanCallback
    @param {Error} error
    @param {Bool} status
###
###*
    @callback numberCallback
    @param {Error} error
    @param {Number} number
###
###*
    @callback browserCallback
    @param {Error} error
    @param {BrowserAPI} browser
###
###*
    @callback appInstanceCallback
    @param {Error} error
    @param {AppInstance} appInstance
###
###*
    @callback appConfigCallback
    @param {Error} error
    @param {AppConfig} appInstance
###
###*
    @callback userCallback
    @param {Error} error
    @param {User}  user
###
###*
    @callback appInstanceEventCallback
    @param {AppInstance | Number | Null} eventArg
###
