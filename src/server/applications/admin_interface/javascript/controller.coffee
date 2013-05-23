CBAdmin         = angular.module("CBAdmin", [])

CBAdmin.controller "AppCtrl", ($scope, $timeout) ->
    $scope.user = cloudBrowser.app.getCreator()
    #change to event based model
    $scope.getApps = () ->
        $timeout ->
            $scope.apps = server.applicationManager.applications
            $scope.getApps()
            null        # avoid memory leak, see https://github.com/angular/angular.js/issues/1522#issuecomment-15921753
        , 100
    $scope.getApps()
    $scope.deleteVB = (mountPoint, browserID) ->
        cloudbrowser.app.closeInstance browserID, $scope.user, () ->
