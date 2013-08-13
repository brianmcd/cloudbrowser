CBHomePage = angular.module("CBHomePage", [])

CBHomePage.controller "MainCtrl", ($scope) ->
    server = cloudbrowser.serverConfig
    currentVirtualBrowser = cloudbrowser.currentVirtualBrowser

    $scope.apps = []

    class App
        @add : (api) ->
            app = {}
            app.api = api
            $scope.$apply ->
                $scope.apps.push(app)

        @remove : (mountPoint) ->
            $scope.$apply ->
                $scope.apps = $.grep $scope.apps, (element, index) ->
                    return element.api.getMountPoint() isnt mountPoint

    server.listApps
        filters :
            public : true
        callback : (apps) ->
            for app in apps
                App.add(app)

    server.addEventListener 'madePublic', (app) ->
        App.add(app)

    server.addEventListener 'madePrivate', (mountPoint) ->
        App.remove(mountPoint)

    $scope.leftClick = (url) ->
        currentVirtualBrowser.redirect(url)

CBHomePage.filter "removeSlash", () ->
    return (input) ->
        return input.substring(1)

