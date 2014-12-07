###*
    The cloudbrowser object that is attached to the global window object
    of every browser.
    It provides the CloudBrowser API to the instance.
    @namespace cloudbrowser
###
Util           = require('./util')
ServerConfig   = require('./server_config')
User           = require('../server/user')
BrowserAPI     = require('./browser')
Authentication = require('./authentication')
cloudbrowserError = require('../shared/cloudbrowser_error')
AppConfig  = require("./application_config")
AppInstance = require('./app_instance')

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
            @auth = new Authentication
                bserver : bserver
                app     : app.parentApp
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
