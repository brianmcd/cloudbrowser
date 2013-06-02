User            = require("./user")
Instance        = require("./instance")
{getMountPoint} = require("../shared/utils")

# Usage : CloudBrowser.app.APImethod
#
# @method #getCreator()
#   Gets the user that created the current application instance.   
#   @return [User] The creator of the current instance.
#
# @method #getUrl()
#   Gets the URL of the application.    
#   @return [String] The application URL.
#
# @method #getDescription()
#   Gets the description of the application as provided in the
#   app_config.json configuration file.    
#   @return [String] The application description.
#
# @method #getMountPoint()
#   Gets the path relative to the root URL at which the application was mounted.     
#   @return [String] The application mountPoint.
#
# @method #getUsers(callback)
#   A list of all the registered users of the application.          
#   @param [Function] callback The **User** array is passed as an argument.
#
# @method #createInstance(callback)
#   Creates a new instance of this application for the creator of the current instance.    
#   @param [Function] callback The error is passed as an argument.
#
# @method #getInstances(callback)
#   Gets all the instances of the current application associated with the creator.    
#   @param [Function] callback The **Instance** array is passed as an argument.
#
# @method #redirect : (url) ->
#   Redirects all clients connected to the current instance to the given URL.    
#   @param [String] url The URL to be redirected to.
#
# @method #addEventListener(event, callback)
#   Registers a listener on the application for an event associated with the creator of the instance.     
#   @param [String]   event    The event to be listened for. CloudBrowser supported events are "Added" and "Removed".
#   @param [Function] callback The **Instance** object is passed as an argument if a new instance has been added. Else, only the ID is passed.
#
# @method #userExists(user, callback)
#   Checks if a user is already registered/signed up with the application.     
#   @param [User] user The user to be tested.
#   @param [Function] callback A boolean indicating existence is passed as an argument.
class ApplicationAPI

    # Constructs an instance of the Application API
    # @param [BrowserServer] bserver An object corresponding to the current browser.
    # @private
    constructor : (bserver) ->

        mountPoint  = getMountPoint(bserver.mountPoint)
        application = bserver.server.applicationManager.find(mountPoint)
        db          = bserver.server.db
        permissionManager = bserver.server.permissionManager

        if bserver.creator?
            creator     = new User(bserver.creator.email, bserver.creator.ns)
            creatorJson = creator.toJson()

        @app =
            getCreator : () ->
                return creator

            getUrl : () ->
                return "http://" + bserver.server.config.domain + ":" + bserver.server.config.port + mountPoint

            getDescription: () ->
                return application.description

            getMountPoint: () ->
                return mountPoint

            getUsers : (callback) ->
                db.collection application.dbName, (err, collection) ->
                    throw err if err
                    collection.find {}, (err, cursor) ->
                        cursor.toArray (err, users) ->
                            throw err if err
                            userList = []
                            for user in users
                                userList.push(new User(user.email,user.ns))
                            callback(userList)

            createInstance : (callback) ->
                application.browsers.create(application, "", creatorJson,
                (err, bsvr) -> callback(err))

            getInstances : (callback) ->
                permissionManager.getBrowserPermRecs creatorJson,
                application.mountPoint, (browserRecs) ->
                    browsers = []
                    for id, browserRec of browserRecs
                        browser = application.browsers.find(id)
                        browsers.push(new Instance(browser, creator))
                    callback(browsers)

            redirect : (url) ->
                bserver.redirect(url)

            addEventListener : (event, callback) ->
                permissionManager.findAppPermRec creatorJson,
                mountPoint, (appRec) ->
                    if appRec
                        if event is "Added" then appRec.on event, (id) ->
                            callback(new Instance(application.browsers.find(id), creator))
                        else appRec.on event, (id) ->
                            callback(id)

            userExists : (user, callback) ->
                db.collection application.dbName, (err, collection) ->
                    if err then throw err
                    collection.findOne user.toJson(), (err, userRec) ->
                        if userRec then callback(true)
                        else callback(false)

module.exports = ApplicationAPI
