CBHomePage = angular.module("CBHomePage", [])

CBHomePage.controller "MainCtrl", ($scope) ->
    server = cloudbrowser.serverConfig
    currentVirtualBrowser = cloudbrowser.currentVirtualBrowser

    $scope.safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase is '$apply' or phase is '$digest'
            if fn then fn()
        else this.$apply(fn)

    $scope.leftClick = (url) -> currentVirtualBrowser.redirect(url)

    $scope.redirectToGithub = (app) ->
        completeUrl = "https://github.com/brianmcd/cloudbrowser/tree/" +
                      "deployment/examples#{app.mountPoint}"
        $scope.leftClick(completeUrl)

    $scope.apps = []

    # Operates on $scope.apps
    class App
        @add : (appConfig) ->
            app =
                api         : appConfig
                url         : appConfig.getUrl()
                mountPoint  : appConfig.getMountPoint()
                description : appConfig.getDescription()

            $scope.apps.push(app)

        @remove : (mountPoint) ->
            for app in $scope.apps when app.api.getMountPoint() is mountPoint
                idx = $scope.apps.indexOf(app)
                return $scope.apps.splice(idx, 1)

    server.listApps
        filters  : {public : true}
        callback : (err, apps) ->
            if err then $scope.safeApply -> $scope.error = err.message
            else $scope.safeApply -> App.add(app) for app in apps

    # Setting up event listeners
    server.addEventListener 'madePublic', (appConfig) ->
        $scope.safeApply -> App.add(appConfig)

    server.addEventListener 'add', (appConfig) ->
        $scope.safeApply -> App.add(appConfig)

    server.addEventListener 'mount', (appConfig) ->
        $scope.safeApply -> App.add(appConfig)

    server.addEventListener 'madePrivate', (mountPoint) ->
        $scope.safeApply -> App.remove(mountPoint)

    server.addEventListener 'remove', (mountPoint) ->
        $scope.safeApply -> App.remove(mountPoint)

    server.addEventListener 'disable', (mountPoint) ->
        $scope.safeApply -> App.remove(mountPoint)

CBHomePage.filter "removeSlash", () -> (input) -> input.substring(1)
