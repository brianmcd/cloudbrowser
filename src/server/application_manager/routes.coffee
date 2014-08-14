module.exports = {
    appInstanceRoute : '/a/:appInstanceID'
    browserRoute : '/a/:appInstanceID/browsers/:browserID/index'
    resourceRoute : '/a/:appInstanceID/browsers/:browserID/:resourceID'
    landingPath : '/landing_path'
    buildBrowserPath : (mountPoint, appInstanceID, browserID) ->
        @concatRoute(mountPoint, "/a/#{appInstanceID}/browsers/#{browserID}/index")

    concatRoute : (base, path) ->
        if base is '/'
            base = ''
        if path.charAt(0) isnt '/'
            path = '/' + path
        # chop trailing '/'
        if path.length>1 and path.charAt(path.length-1) is '/'
            path = path.slice(0,-1)
        return base + path

        
    redirect : (res, route) ->
        if not route then res.send(500)
        res.writeHead 302,
            'Location'      : route
            'Cache-Control' : "max-age=0, must-revalidate"
        res.end()
    notFound : (res, message) ->
        res.send(message, 404)
}