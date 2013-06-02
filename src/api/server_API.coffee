# Usage : CloudBrowser.server.APIMethod
#
# @method #getDomain()
#   Returns the domain as configured in the server_config.json configuration
#   file or as provided through the command line at the time of starting
#   CloudBrowser.    
#   @return [String] The domain at which CloudBrowser is hosted.
#
# @method #getPort()
#   Returns the port as configured in the server_config.json configuration
#   file or as provided through the command line at the time of starting
#   CloudBrowser.    
#   @return [Number] The port at which CloudBrowser is hosted.
#
# @method #getUrl()
#   Returns the URL at which the CloudBrowser server is hosted.    
#   @return [String] The URL at which CloudBrowser is hosted.
class ServerAPI

    compare = (app1, app2) ->
        if(app1.mountPoint < app2.mountPoint)
            return -1
        else if app1.mountPoint > app2.mountPoint
            return 1
        else return 0

    # Constructs an instance of the Server API
    # @param [BrowserServer] bserver The object corresponding to the current browser
    # @private
    constructor : (bserver) ->

        config = bserver.server.config

        @server =
            getDomain : () ->
                return config.domain

            getPort : () ->
                return config.port

            getUrl : () ->
                return "http://" + @getDomain() + ":" + @getPort()

            # Mounts the application whose files are at `path`.
            mount : (path) ->
                bserver.server.applicationManager.create(path)

            # Unmounts the application running at `mountPoint`.
            unmount : (mountPoint) ->
                bserver.server.applicationManager.remove(mountPoint)

            # Lists all the applications mounted by the creator of this browser.
            listApps : () ->
                user = @getCreator()
                bserver.server.applicationManager.get({email:user.getEmail(), ns:user.getNameSpace()})

            getApps :() ->
                list = []
                for mountPoint, app of bserver.server.applicationManager.get()
                    list.push({mountPoint:mountPoint, description:app.description})
                list.sort(compare)
                return list

            # Registers a listener on the server for an event. 
            # @param [String]   event    The event to be listened for. One system supported event is "Added".
            # @param [callback] callback If the event is "Added" then an application object {mountPoint:[String],description:[String]} is passed
            # else only the mountPoint is passed as an argument.
            addEventListener : (event, callback) ->
                bserver.server.applicationManager.on event, (app) ->
                    if event is "Added"
                        callback({mountPoint:app.mountPoint, description:app.description})
                    else
                        callback(app.mountPoint)

module.exports = ServerAPI
