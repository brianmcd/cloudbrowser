(function() {
  var CBLandingPage, baseURL;

  CBLandingPage = angular.module("CBLandingPage", []);

  baseURL = "http://" + server.config.domain + ":" + server.config.port;

  CBLandingPage.controller("UserCtrl", function($scope) {
    var app, query;
    $scope.domain = server.config.domain;
    $scope.port = server.config.port;
    $scope.mountPoint = Utils.getAppMountPoint(bserver.mountPoint, "landing_page");
    $scope.browsers = [];
    app = server.applicationManager.find($scope.mountPoint);
    query = Utils.searchStringtoJSON(location.search);
    $scope.email = query.user;
    server.permissionManager.getBrowserPermRecs($scope.email, $scope.mountPoint, function(browsers) {
      var browser, browserId, _results;
      _results = [];
      for (browserId in browsers) {
        browser = browsers[browserId];
        $scope.browsers.push(browserId);
        _results.push(browsers[browserId] = browser);
      }
      return _results;
    });
    $scope.deleteVB = function(browserId) {
      var browserIdx, err, vb;
      if ($scope.email) {
        vb = app.browsers.find(browserId);
        err = app.browsers.close(vb, $scope.email);
        if (!err) {
          browserIdx = $scope.browsers.indexOf(browserId);
          return $scope.browsers.splice(browserIdx, 1);
        } else {
          return $scope.error = "Permission Denied";
        }
      } else {
        return $scope.error = "Permission Denied";
      }
    };
    $scope.createVB = function() {
      var bserver;
      if ($scope.email) {
        bserver = app.browsers.create(app, "", $scope.email);
        if (bserver) {
          return $scope.browsers.push(bserver.id);
        } else {
          return $scope.error = "Permission Denied";
        }
      } else {
        return $scope.error = "Permission Denied";
      }
    };
    return $scope.logout = function() {
      return bserver.redirect(baseURL + $scope.mountPoint + "/logout");
    };
  });

}).call(this);
