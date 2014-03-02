lodash = require('lodash')

requireClassAndNew = (path, arg1, arg2, arg3) ->
    cl = require(path)
    new cl(arg1, arg2, arg3)


class HttpRoutes
    constructor: (@config, @applicationManager, @sessionManager) ->
        
        userRoute = requireClassAndNew('./user', @applicationManager)
        @user = {
            activate : lodash.bind(userRoute.activate,userRoute),
            deactivate : lodash.bind(userRoute.deactivate,userRoute)
        }

        logoutRoute = requireClassAndNew('./logout', @sessionManager)
        @logout = lodash.bind(logoutRoute.handler, logoutRoute)

        browserRoute = requireClassAndNew('./browser', @applicationManager, @sessionManager)
        @browser = {
            serve : lodash.bind(browserRoute.serve, browserRoute),
            create : lodash.bind(browserRoute.create, browserRoute)
        }

        fileUploadRoute = requireClassAndNew('./file_upload', @sessionManager)
        @fileUpload = lodash.bind(fileUploadRoute.handler, fileUploadRoute)
        
        clientEngineRoute = requireClassAndNew('./client_engine', @config, @applicationManager)
        @clientEngine = lodash.bind(clientEngineRoute.handler, clientEngineRoute)
        
        serveResourceRoute = requireClassAndNew('./serve_resource', @applicationManager)
        @serveResource = lodash.bind(serveResourceRoute.handler, serveResourceRoute)

        serveAppRoute = requireClassAndNew('./serve_application_instance', @applicationManager)
        @serveAppInstance = lodash.bind(serveAppRoute.handler,serveAppRoute)

        googleAuthRoute = requireClassAndNew('./authentication_strategies/google', @applicationManager, @sessionManager)
        @authStrategies = {
            google : lodash.bind(googleAuthRoute.handler, googleAuthRoute)
        }

module.exports = HttpRoutes