// Generated by CoffeeScript 1.6.3
(function() {
  var Async, NwGlobal, app, appConfig;

  Async = require('async');

  NwGlobal = require('nwglobal');

  app = angular.module('CBLandingPage.controllers.appInstance', ['CBLandingPage.models', 'CBLandingPage.services']);

  appConfig = cloudbrowser.parentAppConfig;

  app.controller('AppInstanceCtrl', [
    '$scope', 'cb-mail', 'cb-format', 'cb-appInstanceManager', function($scope, mail, format, appInstanceMgr) {
      var appInstance, grantPermissions;
      appInstance = $scope.appInstance;
      $scope.link = {};
      $scope.error = {};
      $scope.success = {};
      $scope.linkVisible = false;
      $scope.shareForm = {};
      $scope.shareFormOpen = false;
      $scope.confirmDelete = {};
      $scope.showLink = function(entity) {
        if ($scope.isLinkVisible()) {
          $scope.closeLink();
        }
        $scope.link.entity = entity;
        $scope.linkVisible = true;
        return $scope.link.text = entity.api.getURL();
      };
      $scope.isLinkVisible = function() {
        return $scope.linkVisible;
      };
      $scope.closeLink = function() {
        $scope.link.entity = null;
        $scope.link.text = null;
        return $scope.linkVisible = false;
      };
      $scope.tryToRemove = function(entity, removalMethod) {
        $scope.confirmDelete.entityName = entity.name;
        return $scope.confirmDelete.remove = function() {
          return entity.api.close(function(err) {
            return $scope.safeApply(function() {
              if (err) {
                $scope.setError(err);
              } else {
                $scope[removalMethod](entity);
              }
              return $scope.confirmDelete.entityName = null;
            });
          });
        };
      };
      $scope.isProcessing = function() {
        return appInstance.processing;
      };
      $scope.isBrowserTableVisible = function() {
        return appInstance.browserMgr.items.length && appInstance.showOptions;
      };
      $scope.isOptionsVisible = function() {
        return appInstance.showOptions;
      };
      $scope.hasCollaborators = function() {
        if (!appInstance.readerwriters) {
          return false;
        }
        return appInstance.readerwriters.length;
      };
      $scope.create = function() {
        appInstance.processing = true;
        return appInstance.api.createBrowser(function(err, browserConfig) {
          return $scope.safeApply(function() {
            if (err) {
              $scope.setError(err);
              return appInstance.processing = false;
            } else {
              return $scope.addBrowser(browserConfig, appInstance.api);
            }
          });
        });
      };
      $scope.areCollaboratorsVisible = function() {
        return appInstance.showOptions && appInstance.readerwriters.length;
      };
      $scope.toggleOptions = function() {
        return appInstance.showOptions = !appInstance.showOptions;
      };
      appInstance.api.addEventListener('rename', function(name) {
        return $scope.safeApply(function() {
          return appInstance.name = name;
        });
      });
      appInstance.api.addEventListener('share', function(user) {
        return $scope.safeApply(function() {
          return appInstance.readerwriters.push(user);
        });
      });
      $scope.isShareFormOpen = function() {
        return $scope.shareFormOpen;
      };
      $scope.closeShareForm = function() {
        var k, _results;
        $scope.shareFormOpen = false;
        _results = [];
        for (k in $scope.shareForm) {
          _results.push($scope.shareForm[k] = null);
        }
        return _results;
      };
      $scope.openShareForm = function(entity) {
        if ($scope.isShareFormOpen()) {
          $scope.closeShareForm();
        }
        $scope.shareFormOpen = true;
        $scope.shareForm.role = entity.roles[entity.defaultRoleIndex];
        return $scope.shareForm.entity = entity;
      };
      grantPermissions = function(form) {
        var collaborator, entity, role;
        entity = form.entity, role = form.role, collaborator = form.collaborator;
        return Async.series(NwGlobal.Array(function(next) {
          appInstance.processing = true;
          entity.api[role.grantMethod](collaborator, next);
          return $scope.safeApply(function() {
            return $scope.closeShareForm();
          });
        }, function(next) {
          return mail.send({
            to: collaborator,
            url: appConfig.getUrl(),
            from: $scope.user,
            callback: next,
            sharedObj: entity.name,
            mountPoint: appConfig.getMountPoint()
          });
        }), function(err) {
          return $scope.safeApply(function() {
            appInstance.processing = false;
            appInstance.showOptions = true;
            if (err) {
              return $scope.setError(err);
            } else {
              return $scope.success.message = "" + entity.name + " is shared with " + collaborator + ".";
            }
          });
        });
      };
      return $scope.addCollaborator = function() {
        var EMAIL_RE, collaborator;
        collaborator = $scope.shareForm.collaborator;
        EMAIL_RE = /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/;
        if (EMAIL_RE.test(collaborator.toUpperCase())) {
          return appConfig.isUserRegistered(collaborator, function(err, exists) {
            return $scope.safeApply(function() {
              if (err) {
                return $scope.setError(err);
              }
              if (exists) {
                return grantPermissions($scope.shareForm);
              } else {
                return appConfig.addNewUser(collaborator, function() {
                  return $scope.safeApply(function() {
                    return grantPermissions($scope.shareForm);
                  });
                });
              }
            });
          });
        } else {
          return $scope.error.message = "Invalid Collaborator";
        }
      };
    }
  ]);

}).call(this);
