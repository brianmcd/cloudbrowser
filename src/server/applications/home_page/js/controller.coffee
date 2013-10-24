CBHomePage = angular.module("CBHomePage", [])

CBHomePage.controller "MainCtrl", ($scope) ->
    server = cloudbrowser.serverConfig
    currentBrowser = cloudbrowser.currentBrowser

    $scope.safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase is '$apply' or phase is '$digest'
            if fn then fn()
        else this.$apply(fn)

    $scope.leftClick = (url) -> currentBrowser.redirect(url)

    $scope.apps = []

    # Operates on $scope.apps
    class App
        @add : (appConfig) ->
            for app in $scope.apps
                if app.api.getMountPoint() is appConfig.getMountPoint()
                    return
            app =
                api         : appConfig
                url         : appConfig.getUrl()
                name        : appConfig.getName()
                mountPoint  : appConfig.getMountPoint()
                description : appConfig.getDescription()

            $scope.apps.push(app)

        @remove : (mountPoint) ->
            for app in $scope.apps when app.api.getMountPoint() is mountPoint
                idx = $scope.apps.indexOf(app)
                return $scope.apps.splice(idx, 1)

    server.listApps
        filters  : ['public']
        callback : (err, apps) ->
            if err then $scope.safeApply -> $scope.error = err.message
            else $scope.safeApply -> App.add(app) for app in apps

    # Setting up event listeners
    server.addEventListener 'madePublic', (appConfig) ->
        $scope.safeApply -> App.add(appConfig)

    server.addEventListener 'addApp', (appConfig) ->
        $scope.safeApply -> App.add(appConfig)

    server.addEventListener 'mount', (appConfig) ->
        $scope.safeApply -> App.add(appConfig)

    server.addEventListener 'madePrivate', (mountPoint) ->
        $scope.safeApply -> App.remove(mountPoint)

    server.addEventListener 'removeApp', (mountPoint) ->
        $scope.safeApply -> App.remove(mountPoint)

    server.addEventListener 'disable', (mountPoint) ->
        $scope.safeApply -> App.remove(mountPoint)
