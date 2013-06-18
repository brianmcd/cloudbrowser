{compare} = require('./utils')

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
        @return {String}
    ###
    getDomain : () ->
        return _privates[@_index].server.config.domain

    ###*
        Returns the port as configured in the server_config.json configuration
        file or as provided through the command line at the time of starting
        CloudBrowser.    
        @return {Number}
    ###
    getPort : () ->
        return _privates[@_index].server.config.port

    ###*
        Returns the URL at which the CloudBrowser server is hosted.    
        @return {String} 
    ###
    getUrl : () ->
        return "http://" + @getDomain() + ":" + @getPort()

    # Mounts the application whose files are at `path`.
    mount : (path) ->
        _privates[@_index].server.applicationManager.create(path)

    # Unmounts the application running at `mountPoint`.
    unmount : (mountPoint) ->
        _privates[@_index].server.applicationManager.remove(mountPoint)

    # Lists all the applications mounted by the creator of this browser.
    listApps : () ->
        user = @getCreator()
        _privates[@_index].server.applicationManager.get({email:user.getEmail(), ns:user.getNameSpace()})

    # Gets all mounted apps
    getApps :() ->
        list = []
        for mountPoint, app of _privates[@_index].server.applicationManager.get()
            list.push({mountPoint:mountPoint, description:app.description})
        list.sort(compare)
        return list

    addEventListener : (event, callback) ->
        _privates[@_index].server.applicationManager.on event, (app) ->
            if event is "Added"
                callback({mountPoint:app.mountPoint, description:app.description})
            else
                callback(app.mountPoint)

module.exports = ServerConfig
