(function() {
  var CBAdmin;

  CBAdmin = angular.module("CBAdmin", []);

  CBAdmin.controller("AppCtrl", function($scope, $timeout) {
    $scope.user = cloudBrowser.app.getCreator();
    $scope.getApps = function() {
      return $timeout(function() {
        $scope.apps = server.applicationManager.applications;
        $scope.getApps();
        return null;
      }, 100);
    };
    $scope.getApps();
    return $scope.deleteVB = function(mountPoint, browserID) {
      return cloudbrowser.app.closeInstance(browserID, $scope.user, function() {});
    };
  });

}).call(this);
