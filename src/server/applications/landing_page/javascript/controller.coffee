CBLandingPage           = angular.module("CBLandingPage", [])
baseURL                 = "http://" + server.config.domain + ":" + server.config.port

CBLandingPage.controller "UserCtrl", ($scope) ->
    $scope.domain       = server.config.domain
    $scope.port         = server.config.port
    $scope.mountPoint   = Utils.getAppMountPoint bserver.mountPoint, "landing_page"
    $scope.browsers     = []

    app = server.applicationManager.find $scope.mountPoint

    query = Utils.searchStringtoJSON(location.search)

    # Email is assigned at the time of creation of this virtual browser 
    $scope.email = query.user

    # Get all the virtual browsers owned by this user
    server.permissionManager.getBrowserPermRecs $scope.email, $scope.mountPoint, (browsers) ->
        for browserId, browser of browsers
            $scope.browsers.push browserId
            browsers[browserId] = browser

    # Delete a virtual browser
    $scope.deleteVB = (browserId) ->
        if $scope.email
            vb = app.browsers.find(browserId)
            err = app.browsers.close(vb, $scope.email)
            if not err
                browserIdx = $scope.browsers.indexOf browserId
                $scope.browsers.splice(browserIdx, 1)
            else
                $scope.error = "Permission Denied"
        else
            $scope.error = "Permission Denied"

    # Create a virtual browser
    $scope.createVB = () ->
        if $scope.email
            bserver = app.browsers.create(app, "", $scope.email)
            if bserver
                $scope.browsers.push(bserver.id)
            else
                $scope.error = "Permission Denied"
        else
            $scope.error = "Permission Denied"

    $scope.logout = () ->
        bserver.redirect baseURL + $scope.mountPoint + "/logout"
