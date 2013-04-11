(function() {
  var CBAdmin, baseURL;

  CBAdmin = angular.module("CBAdmin", []);

  baseURL = "http://" + server.config.domain + ":" + server.config.port;

  CBAdmin.controller("AppCtrl", function($scope, $timeout) {
    var query;
    query = Utils.searchStringtoJSON(location.search);
    $scope.email = query.user;
    $scope.namespace = query.ns;
    $scope.domain = server.config.domain;
    $scope.port = server.config.port;
    $scope.getApps = function() {
      return $timeout(function() {
        $scope.apps = server.applicationManager.applications;
        $scope.getApps();
        return null;
      }, 100);
    };
    $scope.getApps();
    $scope.click = function(mountPoint) {
      return bserver.redirect(baseURL + mountPoint);
    };
    return $scope.deleteVB = function(mountPoint, browserID) {
      var err, vb;
      vb = server.applicationManager.find(mountPoint).browsers.find(browserID);
      err = server.applicationManager.find(mountPoint).browsers.close(vb, {
        id: $scope.email,
        ns: namespace
      });
      if (err) return console.log("Error detected " + err);
    };
  });

}).call(this);
