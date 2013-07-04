(function() {
  var CBAdmin;

  CBAdmin = angular.module("CBAdmin", []);

  CBAdmin.controller("AppCtrl", function($scope, $timeout) {
    var currentInstance, server;
    currentInstance = cloudbrowser.app.getCurrentInstance();
    server = cloudbrowser.getServerConfig();
    $scope.user = currentInstance.getCreator();
    $scope.getApps = function() {
      return $timeout(function() {
        $scope.apps = server.getApps();
        $scope.getApps();
        return null;
      }, 100);
    };
    $scope.getApps();
    return $scope.deleteVB = function(mountPoint, browserID) {};
  });

}).call(this);
