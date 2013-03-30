(function() {
  var CBAdmin, Util, baseURL;

  CBAdmin = angular.module("CBAdmin", []);

  Util = require('util');

  baseURL = "http://" + config.domain + ":" + config.port;

  CBAdmin.controller("AppCtrl", function($scope, $timeout) {
    $scope.domain = config.domain;
    $scope.port = config.port;
    $scope.getApps = function() {
      return $timeout(function() {
        $scope.apps = server.applicationManager.applications;
        return $scope.getApps();
      }, 100);
    };
    $scope.getApps();
    $scope.click = function(mountPoint) {
      return bserver.redirect(baseURL + mountPoint);
    };
    return $scope.deleteVB = function(mountPoint, browserID) {
      var vb;
      vb = server.applicationManager.find(mountPoint).browsers.find(browserID);
      return server.applicationManager.find(mountPoint).browsers.close(vb);
    };
  });

}).call(this);
