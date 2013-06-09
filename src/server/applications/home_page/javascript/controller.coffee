CBHomePage = angular.module("CBHomePage", [])

CBHomePage.controller "MainCtrl", ($scope) ->
    $scope.apps = CloudBrowser.server.getApps()
    $scope.serverUrl = CloudBrowser.server.getUrl()
    CloudBrowser.server.addEventListener 'Added', (app) ->
        $scope.$apply ->
            $scope.apps.push(app)
    
    $scope.leftClick = (url) ->
        CloudBrowser.app.redirect(url)

CBHomePage.filter "removeSlash", () ->
    return (input) ->
        return input.substring(1)

CBHomePage.filter "mountPointFilter", () ->
    endings = ["landing_page", "authenticate", "password_reset"]
    return (list) ->
        index = 0
        while index < list.length
            if list[index].mountPoint is '/'
                list.splice(index,1)
            mps = list[index].mountPoint.split("/")
            if endings.indexOf(mps[mps.length-1]) isnt -1
                list.splice(index, 1)
            else index++
        return list
    
