module.exports = {
    appInstanceRoute : '/a/:appInstanceID'
    browserRoute : '/a/:appInstanceID/browsers/:browserID/index'
    resourceRoute : '/a/:appInstanceID/browsers/:browserID/:resourceID'
    landingPath : '/landing_path'
    buildBrowserPath : (mountPoint, appInstanceID, browserID) ->
        @concatRoute(mountPoint, "/a/#{appInstanceID}/browsers/#{browserID}/index")

    buildAppInstancePath : (mountPoint, appInstanceID) ->
        @concatRoute(mountPoint, "/a/#{appInstanceID}")

    concatRoute : (base, path) ->
        if base is '/'
            base = ''
        if path.charAt(0) isnt '/'
            path = '/' + path
        # chop trailing '/'
        if path.length>1 and path.charAt(path.length-1) is '/'
            path = path.slice(0,-1)
        return base + path

    redirectToBrowser : (res, mountPoint, appInstanceId, browserID) ->
        @redirect(res, @buildBrowserPath(mountPoint, appInstanceId, browserID))

    redirect : (res, route) ->
        if not route then res.send(500)
        res.writeHead 302,
            'Location'      : route
            'Cache-Control' : "max-age=0, must-revalidate"
        res.end()
        
    notFound : (res, message) ->
        res.status(404).send(message)

    internalError : (res, message) ->
        res.status(500).send(message)

    forbidden : (res, message)->
        res.status(403).send(message)
}