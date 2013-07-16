#Weak = require("weak")

###*
    The CloudBrowser object that is attached to the global window object of every application instance (virtual browser).
    @namespace cloudbrowser
###
KO      = require('./ko')
Browser = require('../server/browser')

class CloudBrowser

    _privates = []

    constructor : (bserver) ->
        # Defining @_index as a read-only property
        Object.defineProperty this, "_index",
            value : _privates.length

        ###*
            @member {BrowserServer} bserver
            @memberOf cloudbrowser
            @instance
            @private
        ###
        ###*
            @member {User} creator
            @memberOf cloudbrowser
            @instance
            @private
        ###
        # Setting private properties
        _privates.push
            bserver : bserver
            creator : if bserver.creator?
                new @app.User(bserver.creator.email, bserver.creator.ns)
            else null

    ###*
        The Application Namespace
        @namespace cloudbrowser.app
    ###
    app :
        User           : require('./user')
        AppConfig      : require('./application_config')
        VirtualBrowser : require('./virtual_browser')
        Model          : require('./model')
        PageManager    : require('./page_manager')
        LocalStrategy  : require('./authentication_strategies').LocalStrategy
        GoogleStrategy : require('./authentication_strategies').GoogleStrategy

    ###*
        Gets the current virtual browser.
        @method
        @return {cloudbrowser.app.VirtualBrowser}
    ###
    getCurrentVirtualBrowser : () ->
        return new @app.VirtualBrowser(_privates[@_index].bserver, _privates[@_index].creator, this)

    ServerConfig : require("./server_config")

    ###*
        Gets the server configuration object
        @method getServerConfig
        @memberof cloudbrowser
        @return {cloudbrowser.ServerConfig}
    ###
    getServerConfig : () -> new @ServerConfig(_privates[@_index].bserver.server)

    Util : require("./util")

    ###*
        Gets the util object
        @method getUtil
        @memberof cloudbrowser
        @return {cloudbrowser.Util}
    ###
    getUtil : () -> new @Util(_privates[@_index].bserver.server.config)

module.exports = (bserver) ->
    bserver.browser.window.cloudbrowser = new CloudBrowser(bserver)
    # TODO : Refactor the code below
    app = bserver.server.applications.find(bserver.mountPoint)
    bserver.browser.window.cloudbrowser.app.shared = app.onFirstInstance || {}
    bserver.browser.window.cloudbrowser.app.local  = if app.onEveryInstance then new app.onEveryInstance() else {}
    # TODO : Fix ko
    bserver.browser.window.cloudbrowser.ko = KO
    # If an app needs server-side knockout, we have to monkey patch
    # some ko functions.
    if bserver.server.config.knockout
        bserver.browser.window.run(Browser.jQScript, "jquery-1.6.2.js")
        bserver.browser.window.run(Browser.koScript, "knockout-latest.debug.js")
        bserver.browser.window.run(Browser.koPatch, "ko-patch.js")

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
