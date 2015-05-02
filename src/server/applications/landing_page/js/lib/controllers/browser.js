// Generated by CoffeeScript 1.8.0
(function() {
  var Async, NwGlobal, app, appConfig, creator, curVB;

  NwGlobal = require('nwglobal');

  Async = require('async');

  curVB = cloudbrowser.currentBrowser;

  creator = curVB.getCreator();

  appConfig = curVB.getAppConfig();

  app = angular.module('CBLandingPage.controllers.browser', ['CBLandingPage.services', 'CBLandingPage.models']);

  app.controller('BrowserCtrl', [
    '$scope', 'cb-mail', 'cb-format', function($scope, mail, format) {
      var browser;
      browser = $scope.browser;
      $scope.error = {};
      $scope.success = {};
      $scope.redirect = function() {
        return browser.redirect();
      };

      /*
       * Filter operations
      $scope.sortBy = (predicate) ->
          $scope.predicate = predicate
          reverseProperty = "#{predicate}-reverse"
          $scope[reverseProperty] = not $scope[reverseProperty]
          $scope.reverse = $scope[reverseProperty]
      
      $scope.showUpArrow = (predicate) ->
          return $scope.predicate is predicate and
          not $scope["#{predicate}-reverse"]
                          
      $scope.showDownArrow = (predicate) ->
          return $scope.predicate is predicate and
          $scope["#{predicate}-reverse"]
       */
      $scope.isEditing = function() {
        return browser.editing;
      };
      $scope.rename = function() {
        if (browser.api.isOwner(creator)) {
          return browser.editing = true;
        } else {
          return $scope.$parent.setError(new Error("Permission Denied"));
        }
      };
      $scope.getURL = function() {
        return browser.api.getURL();
      };
      browser.api.addEventListener('share', function() {
        return browser.updateUsers(function() {
          return $scope.safeApply(function() {});
        });
      });
      return browser.api.addEventListener('rename', (function(_this) {
        return function(name) {
          return $scope.safeApply(function() {
            return browser.name = name;
          });
        };
      })(this));
    }
  ]);

}).call(this);
