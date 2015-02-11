lodash = require('lodash')

sharedRoutes = require("../../shared/routes")

# copy sharedRoutes
routes = lodash.assign({}, sharedRoutes)

# add server specific methods
lodash.assign(routes, 
    {
        redirectToBrowser : (res, mountPoint, appInstanceId, browserID) ->
            @redirect(res, @buildBrowserPath(mountPoint, appInstanceId, browserID))

        redirect : (res, route) ->
            if not route then res.send(500)
            res.writeHead 302,
                "Location"      : route
                "Cache-Control" : "max-age=0, must-revalidate"
            res.end()
            
        notFound : (res, message) ->
            res.status(404).send(message)

        internalError : (res, message) ->
            res.status(500).send(message)

        forbidden : (res, message)->
            res.status(403).send(message)
    }
)

module.exports = routes