CBHomePage = angular.module("CBHomePage", [])

CBHomePage.controller "MainCtrl", ($scope) ->
    server = cloudbrowser.serverConfig
    currentVirtualBrowser = cloudbrowser.currentVirtualBrowser

    $scope.apps = []

    class App
        @add : (app) ->
            $scope.$apply ->
                $scope.apps.push(app)

        @remove : (mountPoint) ->
            $scope.$apply ->
                $scope.apps = $.grep $scope.apps, (element, index) ->
                    return element.getMountPoint() isnt mountPoint

    server.listApps
        filters :
            public : true
        callback : (apps) ->
            $scope.apps = apps

    server.addEventListener 'madePublic', (app) ->
        App.add(app)

    server.addEventListener 'madePrivate', (mountPoint) ->
        App.remove(mountPoint)

    $scope.leftClick = (url) ->
        currentVirtualBrowser.redirect(url)

CBHomePage.filter "removeSlash", () ->
    return (input) ->
        return input.substring(1)

