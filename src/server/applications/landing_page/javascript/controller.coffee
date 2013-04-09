CBLandingPage           = angular.module("CBLandingPage", [])
baseURL                 = "http://" + server.config.domain + ":" + server.config.port

CBLandingPage.controller "UserCtrl", ($scope) ->
    $scope.domain       = server.config.domain
    $scope.port         = server.config.port
    $scope.mountPoint   = Utils.getAppMountPoint bserver.mountPoint, "landing_page"
    $scope.browsers     = []

    app = server.applicationManager.find $scope.mountPoint

    query = Utils.searchStringtoJSON(location.search)

    $scope.email = query.user

    server.permissionManager.getBrowserPermRecs $scope.email, $scope.mountPoint, (browsers) ->
        for browserId, browser of browsers
            $scope.browsers.push browserId
            browsers[browserId] = browser

    $scope.deleteVB = (browserId) ->
        if $scope.email
            server.permissionManager.findBrowserPermRec $scope.email, $scope.mountPoint, browserId, (userPermRec, appPermRec, browserPermRec) ->
                if browserPermRec.permissions.delete
                    server.permissionManager.rmBrowserPermRec $scope.email, $scope.mountPoint, browserId, () ->
                        vb = app.browsers.find(browserId)
                        app.browsers.close(vb)
                        browserIdx = $scope.browsers.indexOf browserId
                        $scope.browsers.splice(browserIdx, 1)
        else
            $scope.error = "Permission Denied"

    $scope.createVB = () ->
        if $scope.email
            server.permissionManager.findAppPermRec $scope.email, $scope.mountPoint, (userPermRec, appPermRec) ->
                if appPermRec.permissions.createbrowsers
                    bserver = app.browsers.create(app, "")
                    $scope.browsers.push(bserver.id)
                    server.permissionManager.addBrowserPermRec $scope.email, $scope.mountPoint, bserver.id, {owner:true, readwrite:true, delete:true}, () ->
                else
                    $scope.error = "Permission Denied"
        else
            $scope.error = "Permission Denied"

    $scope.logout = () ->
        bserver.redirect baseURL + $scope.mountPoint + "/logout"
###
Doesn't work
app.browsers.on 'BrowserAdded', () ->
console.log "Got the event of browser added"
$scope.$apply ->
    $scope.browsers = app.browsers.browsers
    console.log Util.inspect $scope.browsers.browsers
###
