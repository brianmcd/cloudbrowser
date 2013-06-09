(function() {
  var CBHomePage;

  CBHomePage = angular.module("CBHomePage", []);

  CBHomePage.controller("MainCtrl", function($scope) {
    $scope.apps = CloudBrowser.server.getApps();
    $scope.serverUrl = CloudBrowser.server.getUrl();
    CloudBrowser.server.addEventListener('Added', function(app) {
      return $scope.$apply(function() {
        return $scope.apps.push(app);
      });
    });
    return $scope.leftClick = function(url) {
      return CloudBrowser.app.redirect(url);
    };
  });

  CBHomePage.filter("removeSlash", function() {
    return function(input) {
      return input.substring(1);
    };
  });

  CBHomePage.filter("mountPointFilter", function() {
    var endings;
    endings = ["landing_page", "authenticate", "password_reset"];
    return function(list) {
      var index, mps;
      index = 0;
      while (index < list.length) {
        if (list[index].mountPoint === '/') list.splice(index, 1);
        mps = list[index].mountPoint.split("/");
        if (endings.indexOf(mps[mps.length - 1]) !== -1) {
          list.splice(index, 1);
        } else {
          index++;
        }
      }
      return list;
    };
  });

}).call(this);
