CBAdmin = angular.module("CBAdmin", [])

CBAdmin.controller "AppCtrl", ($scope, $timeout) ->
    currentInstance = cloudbrowser.app.getCurrentInstance()
    server          = cloudbrowser.getServerConfig()
    $scope.user = currentInstance.getCreator()
    #change to event based model
    $scope.getApps = () ->
        $timeout ->
            $scope.apps = server.getApps()
            $scope.getApps()
            null        # avoid memory leak, see https://github.com/angular/angular.js/issues/1522#issuecomment-15921753
        , 100
    $scope.getApps()
    $scope.deleteVB = (mountPoint, browserID) ->
        #cloudbrowser.app.closeInstance browserID, $scope.user, () ->
