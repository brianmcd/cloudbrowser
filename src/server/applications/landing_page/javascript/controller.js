(function() {
  var CBLandingPage, Util, baseURL;

  CBLandingPage = angular.module("CBLandingPage", []);

  Util = require('util');

  baseURL = "http://" + server.config.domain + ":" + server.config.port;

  CBLandingPage.controller("UserCtrl", function($scope, $timeout) {
    var Months, addToBrowserList, addToSelected, app, findAndRemove, findInBrowserList, formatDate, getCollaborators, isOwner, query, removeFromBrowserList, removeFromSelected, toggleEnabledDisabled;
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
    findInBrowserList = function(id) {
      var browser;
      browser = $.grep($scope.browserList, function(element, index) {
        return element.id === id;
      });
      return browser[0];
    };
    addToBrowserList = function(browserId) {
      var browser;
      if (!findInBrowserList(browserId)) {
        browser = app.browsers.find(browserId);
        browser.date = formatDate(browser.dateCreated);
        browser.collaborators = getCollaborators(browser);
        browser.on('UserAddedToList', function(user, list) {
          return $scope.safeApply(function() {
            return browser.collaborators = getCollaborators(browser);
          });
        });
        return $scope.safeApply(function() {
          return $scope.browserList.push(browser);
        });
      }
    };
    removeFromBrowserList = function(id) {
      return $scope.safeApply(function() {
        $scope.browserList = $.grep($scope.browserList, function(element, index) {
          return element.id !== id;
        });
        return removeFromSelected(id);
      });
    };
    getCollaborators = function(browser) {
      var collaborators, inList, readwriterRec, usr, _i, _len, _ref;
      inList = function(user, list) {
        var userInList;
        userInList = list.filter(function(item) {
          return item.ns === user.ns && item.email === user.email;
        });
        if (userInList[0]) {
          return userInList[0];
        } else {
          return null;
        }
      };
      collaborators = [];
      _ref = browser.getUsersInList('readwrite');
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        readwriterRec = _ref[_i];
        usr = browser.findUserInList(readwriterRec.user, 'own');
        if (!usr && !inList(readwriterRec.user, collaborators)) {
          collaborators.push(readwriterRec.user);
        }
      }
      return collaborators;
    };
    toggleEnabledDisabled = function(newValue, oldValue) {
      var canRemove, isOwner;
      isOwner = function(callback) {
        var browserID, outstanding, _i, _len, _ref;
        outstanding = $scope.selected.length;
        _ref = $scope.selected;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          browserID = _ref[_i];
          server.permissionManager.findBrowserPermRec($scope.user, $scope.mountPoint, browserID, function(browserRec) {
            if (!browserRec || !browserRec.permissions.own) {
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
      canRemove = function(callback) {
        var browserID, outstanding, _i, _len, _ref;
        outstanding = $scope.selected.length;
        _ref = $scope.selected;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          browserID = _ref[_i];
          server.permissionManager.findBrowserPermRec($scope.user, $scope.mountPoint, browserID, function(browserRec) {
            if (!browserRec || !(browserRec.permissions.own || browserRec.permissions.remove)) {
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
        canRemove(function(val) {
          if (val) {
            return $scope.isDisabled.del = false;
          } else {
            return $scope.isDisabled.del = true;
          }
        });
        return isOwner(function(val) {
          if (val) {
            $scope.isDisabled.share = false;
            return $scope.isDisabled.rename = false;
          } else {
            $scope.isDisabled.share = true;
            return $scope.isDisabled.rename = true;
          }
        });
      } else {
        $scope.isDisabled.open = true;
        $scope.isDisabled.del = true;
        $scope.isDisabled.rename = true;
        return $scope.isDisabled.share = true;
      }
    };
    query = Utils.searchStringtoJSON(location.search);
    $scope.domain = server.config.domain;
    $scope.port = server.config.port;
    $scope.mountPoint = Utils.getAppMountPoint(bserver.mountPoint, "landing_page");
    app = server.applicationManager.find($scope.mountPoint);
    $scope.description = app.description;
    $scope.isDisabled = {
      open: true,
      share: true,
      del: true,
      rename: true
    };
    $scope.browserList = [];
    $scope.selected = [];
    $scope.addingCollaborator = false;
    $scope.predicate = 'date';
    $scope.reverse = true;
    $scope.filterType = 'all';
    $scope.user = {
      email: query.user,
      ns: query.ns
    };
    server.permissionManager.getBrowserPermRecs($scope.user, $scope.mountPoint, function(browserRecs) {
      var browserId, browserRec, _results;
      _results = [];
      for (browserId in browserRecs) {
        browserRec = browserRecs[browserId];
        _results.push(addToBrowserList(browserId));
      }
      return _results;
    });
    server.permissionManager.findAppPermRec($scope.user, $scope.mountPoint, function(appRec) {
      appRec.on('ItemAdded', function(id) {
        return addToBrowserList(id);
      });
      return appRec.on('ItemRemoved', function(id) {
        return removeFromBrowserList(id);
      });
    });
    $scope.$watch('selected.length', function(newValue, oldValue) {
      return toggleEnabledDisabled(newValue, oldValue);
    });
    $scope.createVB = function() {
      if (($scope.user.email != null) && ($scope.user.ns != null)) {
        return app.browsers.create(app, "", $scope.user, function(err, bsvr) {
          if (err) {
            return $scope.safeApply(function() {
              return $scope.error = err.message;
            });
          }
        });
      } else {
        return bserver.redirect(baseURL + $scope.mountPoint + "/logout");
      }
    };
    $scope.logout = function() {
      return bserver.redirect(baseURL + $scope.mountPoint + "/logout");
    };
    $scope.open = function() {
      var browserID, openNewTab, _i, _len, _ref, _results;
      openNewTab = function(browserID) {
        var url, win;
        url = baseURL + $scope.mountPoint + "/browsers/" + browserID + "/index";
        win = window.open(url, '_blank');
      };
      _ref = $scope.selected;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        browserID = _ref[_i];
        _results.push(openNewTab(browserID));
      }
      return _results;
    };
    $scope.remove = function() {
      var browserToBeDeleted, findBrowser, rm;
      findBrowser = function(app, browserID) {
        var vb;
        vb = app.browsers.find(browserID);
        return vb;
      };
      rm = function(browserID, user) {
        return app.browsers.close(findBrowser(app, browserID), user, function(err) {
          if (!err) {
            return removeFromBrowserList(browserID);
          } else {
            return $scope.error = "You do not have the permission to perform this action";
          }
        });
      };
      while ($scope.selected.length > 0) {
        browserToBeDeleted = $scope.selected[0];
        if (($scope.user.email != null) && ($scope.user.ns != null)) {
          rm(browserToBeDeleted, $scope.user);
        }
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
      var getProspectiveCollaborators;
      getProspectiveCollaborators = function() {
        return server.db.collection(app.dbName, function(err, collection) {
          return collection.find({}, function(err, cursor) {
            return cursor.toArray(function(err, users) {
              var browserID, ownerRec, readwriterRec, _i, _j, _k, _len, _len2, _len3, _ref, _ref2, _ref3;
              if (err) throw err;
              if (users != null) {
                _ref = $scope.selected;
                for (_i = 0, _len = _ref.length; _i < _len; _i++) {
                  browserID = _ref[_i];
                  _ref2 = findInBrowserList(browserID).getUsersInList('own');
                  for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
                    ownerRec = _ref2[_j];
                    if (users.length) {
                      findAndRemove(ownerRec.user, users);
                    } else {
                      break;
                    }
                  }
                  _ref3 = findInBrowserList(browserID).getUsersInList('readwrite');
                  for (_k = 0, _len3 = _ref3.length; _k < _len3; _k++) {
                    readwriterRec = _ref3[_k];
                    if (users.length) {
                      findAndRemove(readwriterRec.user, users);
                    } else {
                      break;
                    }
                  }
                }
              }
              return $scope.safeApply(function() {
                return $scope.collaborators = users;
              });
            });
          });
        });
      };
      $scope.addingCollaborator = !$scope.addingCollaborator;
      if ($scope.addingCollaborator) {
        $scope.addingOwner = false;
        return getProspectiveCollaborators();
      }
    };
    isOwner = function(browser, user) {
      if (browser.findUserInList(user, 'own')) {
        return true;
      } else {
        return false;
      }
    };
    $scope.addCollaborator = function() {
      var browser, browserID, _i, _len, _ref, _results;
      _ref = $scope.selected;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        browserID = _ref[_i];
        browser = findInBrowserList(browserID);
        if (isOwner(browser, $scope.user)) {
          _results.push(server.permissionManager.addBrowserPermRec($scope.selectedCollaborator, $scope.mountPoint, browserID, {
            readwrite: true
          }, function(browserRec) {
            if (browserRec) {
              browser = findInBrowserList(browserRec.id);
              return browser.addUserToLists($scope.selectedCollaborator, {
                readwrite: true
              }, function() {
                return $scope.safeApply(function() {
                  $scope.boxMessage = "The selected browsers are now shared with " + $scope.selectedCollaborator.email + " (" + $scope.selectedCollaborator.ns + ")";
                  return $scope.addingCollaborator = false;
                });
              });
            } else {
              throw new Error("Browser permission record for user " + $scope.user.email + " (" + $scope.user.ns + ") and browser " + browserID + " not found");
            }
          }));
        } else {
          _results.push($scope.error = "You do not have the permission to perform this action.");
        }
      }
      return _results;
    };
    $scope.openAddOwnerForm = function() {
      var getProspectiveOwners;
      getProspectiveOwners = function() {
        return server.db.collection(app.dbName, function(err, collection) {
          return collection.find({}, function(err, cursor) {
            return cursor.toArray(function(err, users) {
              var browserID, ownerRec, _i, _j, _len, _len2, _ref, _ref2;
              if (err) throw err;
              if (users != null) {
                _ref = $scope.selected;
                for (_i = 0, _len = _ref.length; _i < _len; _i++) {
                  browserID = _ref[_i];
                  _ref2 = findInBrowserList(browserID).getUsersInList('own');
                  for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
                    ownerRec = _ref2[_j];
                    if (users.length) {
                      findAndRemove(ownerRec.user, users);
                    } else {
                      break;
                    }
                  }
                }
              }
              return $scope.safeApply(function() {
                return $scope.owners = users;
              });
            });
          });
        });
      };
      $scope.addingOwner = !$scope.addingOwner;
      if ($scope.addingOwner) {
        $scope.addingCollaborator = false;
        return getProspectiveOwners();
      }
    };
    $scope.addOwner = function() {
      var browser, browserID, _i, _len, _ref, _results;
      _ref = $scope.selected;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        browserID = _ref[_i];
        browser = findInBrowserList(browserID);
        if (isOwner(browser, $scope.user)) {
          _results.push(server.permissionManager.addBrowserPermRec($scope.selectedOwner, $scope.mountPoint, browserID, {
            own: true,
            remove: true,
            readwrite: true
          }, function(browserRec) {
            if (browserRec) {
              browser = findInBrowserList(browserRec.id);
              return browser.addUserToLists($scope.selectedOwner, {
                own: true,
                remove: true,
                readwrite: true
              }, function() {
                return $scope.safeApply(function() {
                  $scope.boxMessage = "The selected browsers are now co-owned with " + $scope.selectedOwner.email + " (" + $scope.selectedOwner.ns + ")";
                  return $scope.addingOwner = false;
                });
              });
            } else {
              throw new Error("Browser permission record for user " + $scope.user.email + " (" + $scope.user.ns + ") and browser " + browserID + " not found");
            }
          }));
        } else {
          _results.push($scope.error = "You do not have the permission to perform this action.");
        }
      }
      return _results;
    };
    addToSelected = function(browserID) {
      if ($scope.selected.indexOf(browserID) === -1) {
        return $scope.selected.push(browserID);
      }
    };
    removeFromSelected = function(browserID) {
      if ($scope.selected.indexOf(browserID) !== -1) {
        return $scope.selected.splice($scope.selected.indexOf(browserID), 1);
      }
    };
    $scope.select = function($event, browserID) {
      var checkbox;
      checkbox = $event.target;
      if (checkbox.checked) {
        return addToSelected(browserID);
      } else {
        return removeFromSelected(browserID);
      }
    };
    $scope.selectAll = function($event) {
      var action, browser, checkbox, _i, _len, _ref, _results;
      checkbox = $event.target;
      action = checkbox.checked ? addToSelected : removeFromSelected;
      _ref = $scope.browserList;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        browser = _ref[_i];
        _results.push(action(browser.id));
      }
      return _results;
    };
    $scope.getSelectedClass = function(browserID) {
      if ($scope.isSelected(browserID)) {
        return 'highlight';
      } else {
        return '';
      }
    };
    $scope.isSelected = function(browserID) {
      return $scope.selected.indexOf(browserID) >= 0;
    };
    $scope.areAllSelected = function() {
      return $scope.selected.length === $scope.browserList.length;
    };
    $scope.rename = function() {
      var browserID, _i, _len, _ref, _results;
      _ref = $scope.selected;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        browserID = _ref[_i];
        _results.push(findInBrowserList(browserID).editing = true);
      }
      return _results;
    };
    return $scope.clickRename = function(browserID) {
      var browser;
      browser = findInBrowserList(browserID);
      if (isOwner(browser, $scope.user)) return browser.editing = true;
    };
  });

  CBLandingPage.filter("removeSlash", function() {
    return function(input) {
      var mps;
      mps = input.split('/');
      return mps[mps.length - 1];
    };
  });

  CBLandingPage.filter("browserFilter", function() {
    var _this = this;
    return function(list, arg) {
      var browser, filterType, modifiedList, user, _i, _j, _k, _l, _len, _len2, _len3, _len4;
      filterType = arg.type;
      user = arg.user;
      modifiedList = [];
      if (filterType === 'owned') {
        for (_i = 0, _len = list.length; _i < _len; _i++) {
          browser = list[_i];
          if (browser.findUserInList(user, 'own')) modifiedList.push(browser);
        }
      }
      if (filterType === 'notOwned') {
        for (_j = 0, _len2 = list.length; _j < _len2; _j++) {
          browser = list[_j];
          if (browser.findUserInList(user, 'readwrite') && !browser.findUserInList(user, 'own')) {
            modifiedList.push(browser);
          }
        }
      }
      if (filterType === 'shared') {
        for (_k = 0, _len3 = list.length; _k < _len3; _k++) {
          browser = list[_k];
          if (browser.getUsersInList('readwrite').length > 1 || browser.getUsersInList('own').length > 1) {
            modifiedList.push(browser);
          }
        }
      }
      if (filterType === 'notShared') {
        for (_l = 0, _len4 = list.length; _l < _len4; _l++) {
          browser = list[_l];
          if (browser.getUsersInList('own').length === 1 && browser.getUsersInList('readwrite').length === 1) {
            modifiedList.push(browser);
          }
        }
      }
      if (filterType === 'all') modifiedList = list;
      return modifiedList;
    };
  });

}).call(this);
