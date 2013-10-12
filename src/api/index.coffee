###*
    The cloudbrowser object that is attached to the global window object
    of every browser.
    It provides the CloudBrowser API to the instance.
    @namespace cloudbrowser
###
Ko             = require('./ko')
Util           = require('./util')
ServerConfig   = require('./server_config')
BrowserAPI        = require('./browser')
Authentication = require('./authentication')
cloudbrowserError = require('../shared/cloudbrowser_error')

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
        # TODO : Must test this fact
        if bserver.creator?
            creator = new @app.User(bserver.creator.email, bserver.creator.ns)
        else
            # General user with least privileges for applications 
            # where the user identity can not be established due to
            # the absence of the authentication interface
            creator = new @app.User("public", "public")

        @util = new Util(bserver.server.config.emailerConfig)

        @currentBrowser = new BrowserAPI
            browser : bserver
            userCtx : creator
            cbCtx   : this

        if @currentBrowser.getAppConfig().isAuthConfigured()
            @auth = new Authentication
                bserver : bserver
                cbCtx   : this
                mountPoint : bserver.mountPoint
                server  : bserver.server

        @serverConfig = new ServerConfig
            server  : bserver.server
            userCtx : creator
            cbCtx   : this

    ###*
        The Application Namespace
        @namespace cloudbrowser.app
    ###
    app :
        User        : require('./user')
        Model       : require('./model')
        PageManager : require('./page_manager')

module.exports = (bserver) ->
    bserver.browser.window.cloudbrowser = new CloudBrowser(bserver)
    {window} = bserver.browser
    {server} = bserver
    {cloudbrowser} = window

    app = bserver.server.applications.find(bserver.mountPoint)
    if app.localState?
        if typeof app.localState.create is "function"
            property = if typeof app.localState.name is "string"
                           app.localState.name
                       else "local"
            localState = app.localState.create(cloudbrowser)
            if not bserver.getLocalState(property)
                bserver.setLocalState(property, localState)
            else console.log(cloudbrowserError('PROPERTY_EXISTS', "- #{property}"))

    # TODO : Fix ko
    cloudbrowser.ko = Ko

    # If an app needs server-side knockout, we have to monkey patch
    # some ko functions.
    if server.config.knockout
        Browser = require('../server/browser')
        window.run(Browser.jQScript, "jquery-1.6.2.js")
        window.run(Browser.koScript, "knockout-latest.debug.js")
        window.run(Browser.koPatch, "ko-patch.js")

# TODO : Put the documentation of these callbacks somewhere else.
###*
    @callback instanceListCallback 
    @param {Error} error
    @param {Array<BrowserAPI>} instances A list of all the instances associated with the current user.
###
###*
    @callback userListCallback
    @param {Error} error
    @param {Array<cloudbrowser.app.User>} users
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
    @callback appInstanceEventCallback
    @param {AppInstance | Number | Null} eventArg
###
