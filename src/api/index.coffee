###*
    The cloudbrowser object that is attached to the global window object
    of every application instance (virtual browser).
    It provides the CloudBrowser API to the instance.
    @namespace cloudbrowser
###
Ko             = require('./ko')
Util           = require('./util')
Browser        = require('../server/browser')
ServerConfig   = require('./server_config')
VirtualBrowser = require('./virtual_browser')
Authentication = require('./authentication')

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

        @currentVirtualBrowser = new VirtualBrowser
            bserver : bserver
            userCtx : creator
            cbCtx   : this

        if @currentVirtualBrowser.getAppConfig().isAuthConfigured()
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

    # TODO : Refactor the code below
    app = bserver.server.applications.find(bserver.mountPoint)
    bserver.browser.window.cloudbrowser.app.shared = app.onFirstInstance || {}
    bserver.browser.window.cloudbrowser.app.local  = if app.onEveryInstance then new app.onEveryInstance() else {}

    # TODO : Fix ko
    bserver.browser.window.cloudbrowser.ko = Ko

    # If an app needs server-side knockout, we have to monkey patch
    # some ko functions.
    if bserver.server.config.knockout
        bserver.browser.window.run(Browser.jQScript, "jquery-1.6.2.js")
        bserver.browser.window.run(Browser.koScript, "knockout-latest.debug.js")
        bserver.browser.window.run(Browser.koPatch, "ko-patch.js")

# TODO : Put the documentation of these callbacks somewhere else.
###*
    @callback instanceListCallback 
    @param {Array<cloudbrowser.app.VirtualBrowser>} instances A list of all the instances associated with the current user.
###
###*
    @callback userListCallback
    @param {Array<cloudbrowser.app.User>} users
###
###*
    @callback errorCallback
    @param {Error} error 
###
###*
    @callback instanceCallback
    @param {cloudbrowser.app.VirtualBrowser | Number} instance | ID VirtualBrowser if the event is "Added", else ID.
###
###*
    @callback booleanCallback
    @param {Bool | Null} status Null indicates that the user does not have the permission to perform this action.
###
###*
    @callback numberCallback
    @param {Number} number
###
