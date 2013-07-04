{compare} = require('./utils')

###*
    @class cloudbrowser.ServerConfig
###
class ServerConfig

    # Private Properties inside class closure
    _privates = []
    _instance = null

    constructor : (server) ->
        # Singleton
        if _privates.length then return _instance
        else _instance = this

        # Defining @_index as a read-only property
        Object.defineProperty this, "_index",
            value : _privates.length

        # Setting private properties
        _privates.push
            server : server

    ###*
        Returns the domain as configured in the server_config.json configuration
        file or as provided through the command line at the time of starting
        CloudBrowser.    
        @static
        @method getDomain
        @memberOf cloudbrowser.ServerConfig
        @return {String}
    ###
    getDomain : () ->
        return _privates[@_index].server.config.domain

    ###*
        Returns the port as configured in the server_config.json configuration
        file or as provided through the command line at the time of starting
        CloudBrowser.    
        @static
        @method getPort
        @memberOf cloudbrowser.ServerConfig
        @return {Number}
    ###
    getPort : () ->
        return _privates[@_index].server.config.port

    ###*
        Returns the URL at which the CloudBrowser server is hosted.    
        @static
        @method getUrl
        @memberOf cloudbrowser.ServerConfig
        @return {String} 
    ###
    getUrl : () ->
        return "http://" + @getDomain() + ":" + @getPort()

    # Mounts the application whose files are at `path`.
    mount : (path) ->
        _privates[@_index].server.applications.create(path)

    # Unmounts the application running at `mountPoint`.
    unmount : (mountPoint) ->
        _privates[@_index].server.applications.remove(mountPoint)

    # Lists all the applications mounted by the creator of this browser.
    listApps : () ->
        user = @getCreator()
        _privates[@_index].server.applications.get({email:user.getEmail(), ns:user.getNameSpace()})

    ###*
        @typedef appObject
        @property {string} mountPoint
        @property {string} description
    ###
    ###*
        Returns the list of apps mounted on CloudBrowser.    
        @static
        @method getApps
        @memberOf cloudbrowser.ServerConfig
        @return {Array<appObject>} 
    ###
    getApps : () ->
        list = []
        for mountPoint, app of _privates[@_index].server.applications.get()
            list.push({mountPoint:mountPoint, description:app.description})
        list.sort(compare)
        return list

    addEventListener : (event, callback) ->
        _privates[@_index].server.applications.on event, (app) ->
            if event is "Added"
                callback({mountPoint:app.mountPoint, description:app.description})
            else
                callback(app.mountPoint)

module.exports = ServerConfig
