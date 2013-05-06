(function() {
  var CBLandingPage, Util;

  CBLandingPage = angular.module("CBLandingPage", []);

  Util = require('util');

  CBLandingPage.controller("UserCtrl", function($scope, $timeout) {
    var Months, addToInstanceList, addToSelected, findAndRemove, findInInstanceList, formatDate, removeFromInstanceList, removeFromSelected, toggleEnabledDisabled;
    Months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    $scope.safeApply = function(fn) {
      var phase;
      phase = this.$root.$$phase;
      if (phase === '$apply' || phase === '$digest') {
        if (fn) return fn();
      } else {
        return this.$apply(fn);
      }
    };
    formatDate = function(date) {
      var day, hours, minutes, month, time, timeSuffix, year;
      if (!date) return null;
      month = Months[date.getMonth()];
      day = date.getDate();
      year = date.getFullYear();
      hours = date.getHours();
      timeSuffix = hours < 12 ? 'am' : 'pm';
      hours = hours % 12;
      hours = hours ? hours : 12;
      minutes = date.getMinutes();
      minutes = minutes > 10 ? minutes : '0' + minutes;
      time = hours + ":" + minutes + " " + timeSuffix;
      date = day + " " + month + " " + year + " (" + time + ")";
      return date;
    };
    findInInstanceList = function(id) {
      var instance;
      instance = $.grep($scope.instanceList, function(element, index) {
        return element.id === id;
      });
      return instance[0];
    };
    addToInstanceList = function(instanceID) {
      var instance;
      if (!findInInstanceList(instanceID)) {
        instance = CloudBrowser.app.getInstanceInfo(instanceID);
        instance.date = formatDate(instance.date);
        instance.owners = CloudBrowser.permissionManager.getInstanceOwners(instance.id);
        instance.collaborators = CloudBrowser.permissionManager.getInstanceReaderWriters(instance.id);
        CloudBrowser.app.registerListenerOnInstanceEvent(instance.id, 'InstanceShared', function() {
          return $scope.safeApply(function() {
            instance.collaborators = CloudBrowser.permissionManager.getInstanceReaderWriters(instance.id);
            return instance.owners = CloudBrowser.permissionManager.getInstanceOwners(instance.id);
          });
        });
        return $scope.safeApply(function() {
          return $scope.instanceList.push(instance);
        });
      }
    };
    removeFromInstanceList = function(id) {
      return $scope.safeApply(function() {
        var oldLength;
        oldLength = $scope.instanceList.length;
        $scope.instanceList = $.grep($scope.instanceList, function(element, index) {
          return element.id !== id;
        });
        if (oldLength > $scope.instanceList.length) return removeFromSelected(id);
      });
    };
    toggleEnabledDisabled = function(newValue, oldValue) {
      var checkPermission;
      checkPermission = function(type, callback) {
        var instanceID, outstanding, _i, _len, _ref;
        outstanding = $scope.selected.length;
        _ref = $scope.selected;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          instanceID = _ref[_i];
          CloudBrowser.permissionManager.checkInstancePermissions(type, instanceID, CloudBrowser.app.getCreator(), function(hasPermission) {
            if (!hasPermission) {
              return $scope.safeApply(function() {
                return callback(false);
              });
            } else {
              return outstanding--;
            }
          });
        }
        return process.nextTick(function() {
          if (!outstanding) {
            return $scope.safeApply(function() {
              return callback(true);
            });
          } else {
            return process.nextTick(arguments.callee);
          }
        });
      };
      if (newValue > 0) {
        $scope.isDisabled.open = false;
        checkPermission({
          remove: true
        }, function(canRemove) {
          return $scope.isDisabled.del = !canRemove;
        });
        return checkPermission({
          own: true
        }, function(isOwner) {
          $scope.isDisabled.share = !isOwner;
          return $scope.isDisabled.rename = !isOwner;
        });
      } else {
        $scope.isDisabled.open = true;
        $scope.isDisabled.del = true;
        $scope.isDisabled.rename = true;
        return $scope.isDisabled.share = true;
      }
    };
    $scope.description = CloudBrowser.app.getDescription();
    $scope.user = CloudBrowser.app.getCreator();
    $scope.mountPoint = CloudBrowser.app.getMountPoint();
    $scope.isDisabled = {
      open: true,
      share: true,
      del: true,
      rename: true
    };
    $scope.instanceList = [];
    $scope.selected = [];
    $scope.addingCollaborator = false;
    $scope.confirmDelete = false;
    $scope.addingOwner = false;
    $scope.predicate = 'date';
    $scope.reverse = true;
    $scope.filterType = 'all';
    CloudBrowser.app.getInstanceIDs($scope.user, function(instanceIDs) {
      var instanceID, _i, _len, _results;
      _results = [];
      for (_i = 0, _len = instanceIDs.length; _i < _len; _i++) {
        instanceID = instanceIDs[_i];
        _results.push(addToInstanceList(instanceID));
      }
      return _results;
    });
    CloudBrowser.app.registerListenerOnEvent('ItemAdded', function(id) {
      return addToInstanceList(id);
    });
    CloudBrowser.app.registerListenerOnEvent('ItemRemoved', function(id) {
      return removeFromInstanceList(id);
    });
    $scope.$watch('selected.length', function(newValue, oldValue) {
      return toggleEnabledDisabled(newValue, oldValue);
    });
    $scope.createVB = function() {
      return CloudBrowser.app.createInstance(function(err) {
        if (err) {
          return $scope.safeApply(function() {
            return $scope.error = err.message;
          });
        }
      });
    };
    $scope.logout = function() {
      return CloudBrowser.app.logout();
    };
    $scope.open = function() {
      var instanceID, openNewTab, _i, _len, _ref, _results;
      openNewTab = function(instanceID) {
        var url, win;
        url = CloudBrowser.app.getUrl() + "/browsers/" + instanceID + "/index";
        win = window.open(url, '_blank');
      };
      _ref = $scope.selected;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        instanceID = _ref[_i];
        _results.push(openNewTab(instanceID));
      }
      return _results;
    };
    $scope.remove = function() {
      while ($scope.selected.length > 0) {
        CloudBrowser.app.closeInstance($scope.selected[0], $scope.user, function(err) {
          if (err) {
            return $scope.error = "You do not have the permission to perform this action";
          } else if ($scope.selected[0] != null) {
            return removeFromInstanceList($scope.selected[0]);
          }
        });
      }
      return $scope.confirmDelete = false;
    };
    findAndRemove = function(user, list) {
      var i, _ref;
      for (i = 0, _ref = list.length - 1; 0 <= _ref ? i <= _ref : i >= _ref; 0 <= _ref ? i++ : i--) {
        if (list[i].email === user.email && list[i].ns === user.ns) break;
      }
      if (i < list.length) return list.splice(i, 1);
    };
    $scope.openCollaborateForm = function() {
      $scope.addingCollaborator = !$scope.addingCollaborator;
      if ($scope.addingCollaborator) {
        $scope.addingOwner = false;
        return CloudBrowser.app.getUsers(function(users) {
          var index, instanceID, _i, _len, _ref;
          if (users != null) {
            _ref = $scope.selected;
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              instanceID = _ref[_i];
              index = 0;
              while (index < users.length) {
                if (CloudBrowser.permissionManager.isInstanceOwner(instanceID, users[index]) || CloudBrowser.permissionManager.isInstanceReaderWriter(instanceID, users[index])) {
                  findAndRemove(users[index], users);
                } else {
                  index++;
                }
              }
            }
          }
          return $scope.safeApply(function() {
            return $scope.collaborators = users;
          });
        });
      }
    };
    $scope.addCollaborator = function() {
      var instanceID, _i, _len, _ref, _results;
      _ref = $scope.selected;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        instanceID = _ref[_i];
        if (CloudBrowser.permissionManager.isInstanceOwner(instanceID, $scope.user)) {
          _results.push(CloudBrowser.permissionManager.grantInstancePermissions({
            readwrite: true
          }, $scope.selectedCollaborator, instanceID, function() {
            return $scope.safeApply(function() {
              $scope.boxMessage = "The selected instances are now shared with " + $scope.selectedCollaborator.email + " (" + $scope.selectedCollaborator.ns + ")";
              return $scope.addingCollaborator = false;
            });
          }));
        } else {
          _results.push($scope.error = "You do not have the permission to perform this action.");
        }
      }
      return _results;
    };
    $scope.openAddOwnerForm = function() {
      $scope.addingOwner = !$scope.addingOwner;
      if ($scope.addingOwner) {
        $scope.addingCollaborator = false;
        return CloudBrowser.app.getUsers(function(users) {
          var index, instanceID, _i, _len, _ref;
          if (users != null) {
            _ref = $scope.selected;
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              instanceID = _ref[_i];
              index = 0;
              while (index < users.length) {
                if (CloudBrowser.permissionManager.isInstanceOwner(instanceID, users[index])) {
                  findAndRemove(users[index], users);
                } else {
                  index++;
                }
              }
            }
          }
          return $scope.safeApply(function() {
            return $scope.owners = users;
          });
        });
      }
    };
    $scope.addOwner = function() {
      var instanceID, _i, _len, _ref, _results;
      _ref = $scope.selected;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        instanceID = _ref[_i];
        if (CloudBrowser.permissionManager.isInstanceOwner(instanceID, $scope.user)) {
          _results.push(CloudBrowser.permissionManager.grantInstancePermissions({
            own: true,
            remove: true,
            readwrite: true
          }, $scope.selectedOwner, instanceID, function() {
            return $scope.safeApply(function() {
              $scope.boxMessage = "The selected instances are now co-owned with " + $scope.selectedOwner.email + " (" + $scope.selectedOwner.ns + ")";
              return $scope.addingOwner = false;
            });
          }));
        } else {
          _results.push($scope.error = "You do not have the permission to perform this action.");
        }
      }
      return _results;
    };
    addToSelected = function(instanceID) {
      if ($scope.selected.indexOf(instanceID) === -1) {
        return $scope.selected.push(instanceID);
      }
    };
    removeFromSelected = function(instanceID) {
      if ($scope.selected.indexOf(instanceID) !== -1) {
        return $scope.selected.splice($scope.selected.indexOf(instanceID), 1);
      }
    };
    $scope.select = function($event, instanceID) {
      var checkbox;
      checkbox = $event.target;
      if (checkbox.checked) {
        return addToSelected(instanceID);
      } else {
        return removeFromSelected(instanceID);
      }
    };
    $scope.selectAll = function($event) {
      var action, checkbox, instance, _i, _len, _ref, _results;
      checkbox = $event.target;
      action = checkbox.checked ? addToSelected : removeFromSelected;
      _ref = $scope.instanceList;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        instance = _ref[_i];
        _results.push(action(instance.id));
      }
      return _results;
    };
    $scope.getSelectedClass = function(instanceID) {
      if ($scope.isSelected(instanceID)) {
        return 'highlight';
      } else {
        return '';
      }
    };
    $scope.isSelected = function(instanceID) {
      return $scope.selected.indexOf(instanceID) >= 0;
    };
    $scope.areAllSelected = function() {
      return $scope.selected.length === $scope.instanceList.length;
    };
    $scope.rename = function() {
      var instanceID, _i, _len, _ref, _results;
      _ref = $scope.selected;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        instanceID = _ref[_i];
        _results.push(findInInstanceList(instanceID).editing = true);
      }
      return _results;
    };
    return $scope.clickRename = function(instanceID) {
      var instance;
      instance = findInInstanceList(instanceID);
      if (isInstanceOwner(instance, $scope.user)) return instance.editing = true;
    };
  });

  CBLandingPage.filter("removeSlash", function() {
    return function(input) {
      var mps;
      mps = input.split('/');
      return mps[mps.length - 1];
    };
  });

  CBLandingPage.filter("instanceFilter", function() {
    var _this = this;
    return function(list, arg) {
      var filterType, instance, modifiedList, user, _i, _j, _k, _l, _len, _len2, _len3, _len4;
      filterType = arg.type;
      user = arg.user;
      modifiedList = [];
      if (filterType === 'owned') {
        for (_i = 0, _len = list.length; _i < _len; _i++) {
          instance = list[_i];
          if (CloudBrowser.permissionManager.isInstanceOwner(instance.id, user)) {
            modifiedList.push(instance);
          }
        }
      }
      if (filterType === 'notOwned') {
        for (_j = 0, _len2 = list.length; _j < _len2; _j++) {
          instance = list[_j];
          if (!CloudBrowser.permissionManager.isInstanceOwner(instance.id, user)) {
            modifiedList.push(instance);
          }
        }
      }
      if (filterType === 'shared') {
        for (_k = 0, _len3 = list.length; _k < _len3; _k++) {
          instance = list[_k];
          if (CloudBrowser.permissionManager.getInstanceReaderWriters(instance.id).length || CloudBrowser.permissionManager.getInstanceOwners(instance.id).length > 1) {
            modifiedList.push(instance);
          }
        }
      }
      if (filterType === 'notShared') {
        for (_l = 0, _len4 = list.length; _l < _len4; _l++) {
          instance = list[_l];
          if (CloudBrowser.permissionManager.getInstanceOwners(instance.id).length === 1 && !CloudBrowser.permissionManager.getInstanceReaderWriters(instance.id).length) {
            modifiedList.push(instance);
          }
        }
      }
      if (filterType === 'all') modifiedList = list;
      return modifiedList;
    };
  });

}).call(this);
