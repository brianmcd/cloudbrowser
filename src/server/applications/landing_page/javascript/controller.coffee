CBLandingPage           = angular.module("CBLandingPage", [])
baseURL                 = "http://" + config.domain + ":" + config.port
Util                    = require('util')

CBLandingPage.controller "UserCtrl", ($scope) ->
    getAppMountPoint = (url) ->
        urlComponents   = bserver.mountPoint.split("/")
        componentIndex  = 1
        mountPoint      = ""
        while urlComponents[componentIndex] isnt "landing_page" and componentIndex < urlComponents.length
            mountPoint += "/" + urlComponents[componentIndex++]
        return mountPoint

    $scope.domain       = config.domain
    $scope.port         = config.port
    $scope.mountPoint   = getAppMountPoint bserver.mountPoint
    $scope.browsers     = []

    app = server.applicationManager.find $scope.mountPoint

    #dictionary of all the query key value pairs
    searchStringtoJSON = (searchString) ->
        search  = searchString.split("&")
        query   = {}
        for s in search
            pair = s.split("=")
            query[decodeURIComponent pair[0]] = decodeURIComponent pair[1]
        return query

    search = location.search
    if search[0] == "?"
        search = search.slice(1)

    query = searchStringtoJSON(search)

    $scope.email = query.user

    server.permissionManager.getBrowserPermRecs $scope.email, $scope.mountPoint, (browsers) ->
        for browserId, browser of browsers
            $scope.browsers.push browserId
            browsers[browserId] = browser

    $scope.deleteVB = (browserId) ->
        console.log browsers[browserId]
        if $scope.email and browsers[browserId].permissions.delete
            server.permissionManager.rmBrowserPermRec $scope.email, $scope.mountPoint, browserID, () ->
                console.log "Deleted"
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
                        console.log "Browser added to perm record " + bserver.id
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
