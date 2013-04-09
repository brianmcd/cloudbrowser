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
      if ($scope.email) {
        return server.permissionManager.findBrowserPermRec($scope.email, $scope.mountPoint, browserId, function(userPermRec, appPermRec, browserPermRec) {
          if (browserPermRec.permissions["delete"]) {
            return server.permissionManager.rmBrowserPermRec($scope.email, $scope.mountPoint, browserId, function() {
              var browserIdx, vb;
              vb = app.browsers.find(browserId);
              app.browsers.close(vb);
              browserIdx = $scope.browsers.indexOf(browserId);
              return $scope.browsers.splice(browserIdx, 1);
            });
          }
        });
      } else {
        return $scope.error = "Permission Denied";
      }
    };
    $scope.createVB = function() {
      if ($scope.email) {
        return server.permissionManager.findAppPermRec($scope.email, $scope.mountPoint, function(userPermRec, appPermRec) {
          var bserver;
          if (appPermRec.permissions.createbrowsers) {
            bserver = app.browsers.create(app, "");
            $scope.browsers.push(bserver.id);
            return server.permissionManager.addBrowserPermRec($scope.email, $scope.mountPoint, bserver.id, {
              owner: true,
              readwrite: true,
              "delete": true
            }, function() {});
          } else {
            return $scope.error = "Permission Denied";
          }
        });
      } else {
        return $scope.error = "Permission Denied";
      }
    };
    return $scope.logout = function() {
      return bserver.redirect(baseURL + $scope.mountPoint + "/logout");
    };
  });

  /*
  Doesn't work
  app.browsers.on 'BrowserAdded', () ->
  console.log "Got the event of browser added"
  $scope.$apply ->
      $scope.browsers = app.browsers.browsers
      console.log Util.inspect $scope.browsers.browsers
  */

}).call(this);
