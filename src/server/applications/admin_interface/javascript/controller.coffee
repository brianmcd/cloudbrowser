CBAdmin         = angular.module("CBAdmin", [])
baseURL = "http://" + server.config.domain + ":" + server.config.port

CBAdmin.controller "AppCtrl", ($scope, $timeout) ->
    query = Utils.searchStringtoJSON(location.search)
    $scope.email = query.user
    $scope.namespace = query.ns
    $scope.domain = server.config.domain
    $scope.port = server.config.port
    $scope.getApps = () ->
        $timeout ->
            $scope.apps = server.applicationManager.applications
            $scope.getApps()
            null        # avoid memory leak, see https://github.com/angular/angular.js/issues/1522#issuecomment-15921753
        , 100
    $scope.getApps()
    $scope.click = (mountPoint) ->
        bserver.redirect(baseURL + mountPoint)
    $scope.deleteVB = (mountPoint, browserID) ->
        vb = server.applicationManager.find(mountPoint).browsers.find(browserID)
        err = server.applicationManager.find(mountPoint).browsers.close(vb, {id:$scope.email, ns:namespace})
        if err then console.log "Error detected " + err
