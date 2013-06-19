#Weak = require("weak")

###*
    The CloudBrowser object that is attached to the global window object of every application instance (virtual browser).
    @namespace cloudbrowser
###

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
    #cleaned = false
    # TODO: is this weak ref required?
    #window  = Weak(browser.window, () -> cleaned = true)
    #browser = Weak(browser, () -> cleaned = true)

    bserver.browser.window.cloudbrowser = new CloudBrowser(bserver)

###*
    @callback instanceListCallback 
    @param {Array<VirtualBrowser>} instances A list of all the instances associated with the current user.
###
###*
    @callback userListCallback
    @param {Array<User>} users
###
###*
    @callback errorCallback
    @param {Error} error 
###
###*
    @callback instanceCallback
    @param {VirtualBrowser | Number} instance | ID VirtualBrowser if the event is "Added", else ID.
###
###*
    @callback booleanCallback
    @param {Bool | Null} status Null indicates that the user does not have the permission to perform this action.
###
###*
    @callback numberCallback
    @param {Number} number
###
