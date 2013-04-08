(function() {
  var CBLandingPage, Util, baseURL;

  CBLandingPage = angular.module("CBLandingPage", []);

  baseURL = "http://" + config.domain + ":" + config.port;

  Util = require('util');

  CBLandingPage.controller("UserCtrl", function($scope) {
    var app, getAppMountPoint, query, search, searchStringtoJSON;
    getAppMountPoint = function(url) {
      var componentIndex, mountPoint, urlComponents;
      urlComponents = bserver.mountPoint.split("/");
      componentIndex = 1;
      mountPoint = "";
      while (urlComponents[componentIndex] !== "landing_page" && componentIndex < urlComponents.length) {
        mountPoint += "/" + urlComponents[componentIndex++];
      }
      return mountPoint;
    };
    $scope.domain = config.domain;
    $scope.port = config.port;
    $scope.mountPoint = getAppMountPoint(bserver.mountPoint);
    $scope.browsers = [];
    app = server.applicationManager.find($scope.mountPoint);
    searchStringtoJSON = function(searchString) {
      var pair, query, s, search, _i, _len;
      search = searchString.split("&");
      query = {};
      for (_i = 0, _len = search.length; _i < _len; _i++) {
        s = search[_i];
        pair = s.split("=");
        query[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1]);
      }
      return query;
    };
    search = location.search;
    if (search[0] === "?") search = search.slice(1);
    query = searchStringtoJSON(search);
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
      console.log(browsers[browserId]);
      if ($scope.email && browsers[browserId].permissions["delete"]) {
        return server.permissionManager.rmBrowserPermRec($scope.email, $scope.mountPoint, browserID, function() {
          var browserIdx, vb;
          console.log("Deleted");
          vb = app.browsers.find(browserId);
          app.browsers.close(vb);
          browserIdx = $scope.browsers.indexOf(browserId);
          return $scope.browsers.splice(browserIdx, 1);
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
            }, function() {
              return console.log("Browser added to perm record " + bserver.id);
            });
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
