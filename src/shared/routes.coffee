browsers = "b"
appInstances = "a"
components = "c"

module.exports = {
    appInstanceRoute : "/#{appInstances}/:appInstanceID"
    browserRoute : "/#{appInstances}/:appInstanceID/#{browsers}/:browserID/index"
    resourceRoute : "/#{appInstances}/:appInstanceID/#{browsers}/:browserID/:resourceID"
    componentRoute : "/#{appInstances}/:appInstanceID/#{browsers}/:browserID/#{components}/:componentId"
    landingPath : "/landing_path"
    buildBrowserPath : (mountPoint, appInstanceID, browserID) ->
        @concatRoute(mountPoint, "/#{appInstances}/#{appInstanceID}/#{browsers}/#{browserID}/index")

    buildAppInstancePath : (mountPoint, appInstanceID) ->
        @concatRoute(mountPoint, "/#{appInstances}/#{appInstanceID}")

    buildComponentPath : (mountPoint, appInstanceID, browserID, componentId) ->
        @concatRoute(mountPoint, "/#{appInstances}/#{appInstanceID}/#{browsers}/#{browserID}/#{components}/#{componentId}")

    concatRoute : (base, path) ->
        if base is "/"
            base = ""
        if path.charAt(0) isnt "/"
            path = "/" + path
        # chop trailing "/"
        if path.length>1 and path.charAt(path.length-1) is "/"
            path = path.slice(0,-1)
        return base + path
}