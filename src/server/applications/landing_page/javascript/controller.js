(function() {
  var CBLandingPage, Util, baseURL;

  CBLandingPage = angular.module("CBLandingPage", []);

  Util = require('util');

  baseURL = "http://" + server.config.domain + ":" + server.config.port;

  CBLandingPage.controller("UserCtrl", function($scope, $timeout) {
    var Months, addToSelected, app, findAndRemove, formatDate, getBrowsers, getCollaborators, isOwner, namespace, query, removeFromSelected, repeatedlyGetBrowsers, toggleEnabledDisabled;
    Months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
    getBrowsers = function(browserList, user, mp) {
      return server.permissionManager.getBrowserPermRecs(user, mp, function(browserRecs) {
        var browser, browserId, browserRec, _results;
        _results = [];
        for (browserId in browserRecs) {
          browserRec = browserRecs[browserId];
          browser = app.browsers.find(browserId);
          browser.date = formatDate(browser.dateCreated);
          browser.collaborators = getCollaborators(browser);
          _results.push(browserList[browserId] = browser);
        }
        return _results;
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
        outstanding = $scope.selected.number;
        _ref = $scope.selected.browserIDs;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          browserID = _ref[_i];
          server.permissionManager.findBrowserPermRec({
            email: $scope.email,
            ns: namespace
          }, $scope.mountPoint, browserID, function(browserRec) {
            if (!browserRec || !browserRec.permissions.own) {
              return callback(false);
            } else {
              return outstanding--;
            }
          });
        }
        return process.nextTick(function() {
          if (!outstanding) {
            return callback(true);
          } else {
            return process.nextTick(arguments.callee);
          }
        });
      };
      canRemove = function(callback) {
        var browserID, outstanding, _i, _len, _ref;
        outstanding = $scope.selected.number;
        _ref = $scope.selected.browserIDs;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          browserID = _ref[_i];
          server.permissionManager.findBrowserPermRec({
            email: $scope.email,
            ns: namespace
          }, $scope.mountPoint, browserID, function(browserRec) {
            if (!browserRec || !(browserRec.permissions.own || browserRec.permissions.remove)) {
              return callback(false);
            } else {
              return outstanding--;
            }
          });
        }
        return process.nextTick(function() {
          if (!outstanding) {
            return callback(true);
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
    namespace = query.ns;
    app = server.applicationManager.find($scope.mountPoint);
    $scope.description = app.description;
    $scope.email = query.user;
    $scope.isDisabled = {
      open: true,
      share: true,
      del: true,
      rename: true
    };
    $scope.selected = {
      browserIDs: [],
      number: 0
    };
    $scope.browserList = {};
    $scope.addingCollaborator = false;
    repeatedlyGetBrowsers = function() {
      return $timeout(function() {
        $scope.browserList = {};
        getBrowsers($scope.browserList, {
          email: $scope.email,
          ns: namespace
        }, $scope.mountPoint);
        repeatedlyGetBrowsers();
        return null;
      }, 100);
    };
    repeatedlyGetBrowsers();
    $scope.$watch('selected.number', function(newValue, oldValue) {
      return toggleEnabledDisabled(newValue, oldValue);
    });
    $scope.createVB = function() {
      if ($scope.email) {
        return app.browsers.create(app, "", {
          email: $scope.email,
          ns: namespace
        }, function(bsvr) {
          if (bsvr) {
            bsvr.date = formatDate(bsvr.dateCreated);
            return $scope.browserList[bsvr.id] = bsvr;
          } else {
            return $scope.error = "Permission Denied";
          }
        });
      } else {
        return $scope.error = "Permission Denied";
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
      _ref = $scope.selected.browserIDs;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        browserID = _ref[_i];
        _results.push(openNewTab(browserID));
      }
      return _results;
    };
    $scope.remove = function() {
      var browserToBeDeleted, findBrowser, rm, _results;
      findBrowser = function(app, browserID) {
        var vb;
        vb = app.browsers.find(browserID);
        return vb;
      };
      rm = function(browserID, user) {
        return app.browsers.close(findBrowser(app, browserID), user, function(err) {
          if (!err) {
            delete $scope.browserList[browserID];
            $scope.selected.browserIDs.splice(0, 1);
            return $scope.selected.number--;
          } else {
            return $scope.error = err;
          }
        });
      };
      _results = [];
      while ($scope.selected.browserIDs.length > 0) {
        browserToBeDeleted = $scope.selected.browserIDs[0];
        if ($scope.email != null) {
          _results.push(rm(browserToBeDeleted, {
            email: $scope.email,
            ns: namespace
          }));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
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
                _ref = $scope.selected.browserIDs;
                for (_i = 0, _len = _ref.length; _i < _len; _i++) {
                  browserID = _ref[_i];
                  _ref2 = $scope.browserList[browserID].getUsersInList('own');
                  for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
                    ownerRec = _ref2[_j];
                    if (users.length) {
                      findAndRemove(ownerRec.user, users);
                    } else {
                      break;
                    }
                  }
                  _ref3 = $scope.browserList[browserID].getUsersInList('readwrite');
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
              return $scope.collaborators = users;
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
      _ref = $scope.selected.browserIDs;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        browserID = _ref[_i];
        browser = $scope.browserList[browserID];
        if (isOwner(browser, {
          email: $scope.email,
          ns: namespace
        })) {
          _results.push(server.permissionManager.addBrowserPermRec($scope.selectedCollaborator, $scope.mountPoint, browserID, {
            readwrite: true
          }, function(browserRec) {
            if (browserRec) {
              browser = $scope.browserList[browserRec.id];
              return browser.addUserToLists($scope.selectedCollaborator, {
                readwrite: true
              }, function() {
                $scope.boxMessage = "The selected browsers are now shared with " + $scope.selectedCollaborator;
                return $scope.openCollaborateForm();
              });
            } else {
              return $scope.error = "Error";
            }
          }));
        } else {
          _results.push($scope.error = "Permission Denied");
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
                _ref = $scope.selected.browserIDs;
                for (_i = 0, _len = _ref.length; _i < _len; _i++) {
                  browserID = _ref[_i];
                  _ref2 = $scope.browserList[browserID].getUsersInList('own');
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
              return $scope.owners = users;
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
      _ref = $scope.selected.browserIDs;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        browserID = _ref[_i];
        browser = $scope.browserList[browserID];
        if (isOwner(browser, {
          email: $scope.email,
          ns: namespace
        })) {
          _results.push(server.permissionManager.addBrowserPermRec($scope.selectedOwner, $scope.mountPoint, browserID, {
            own: true,
            remove: true,
            readwrite: true
          }, function(browserRec) {
            if (browserRec) {
              browser = $scope.browserList[browserRec.id];
              return browser.addUserToLists($scope.selectedOwner, {
                own: true,
                remove: true,
                readwrite: true
              }, function() {
                $scope.boxMessage = "The selected browsers are now co-owned with " + $scope.selectedOwner;
                return $scope.openAddOwnerForm();
              });
            } else {
              return $scope.error = "Error";
            }
          }));
        } else {
          _results.push($scope.error = "Permission Denied");
        }
      }
      return _results;
    };
    addToSelected = function(browserID) {
      if ($scope.selected.browserIDs.indexOf(browserID) === -1) {
        $scope.selected.number++;
        return $scope.selected.browserIDs.push(browserID);
      }
    };
    removeFromSelected = function(browserID) {
      if ($scope.selected.browserIDs.indexOf(browserID) !== -1) {
        $scope.selected.number--;
        return $scope.selected.browserIDs.splice($scope.selected.browserIDs.indexOf(browserID), 1);
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
      var action, browser, browserID, checkbox, _ref, _results;
      checkbox = $event.target;
      action = checkbox.checked ? addToSelected : removeFromSelected;
      _ref = $scope.browserList;
      _results = [];
      for (browserID in _ref) {
        browser = _ref[browserID];
        _results.push(action(browserID));
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
      return $scope.selected.browserIDs.indexOf(browserID) >= 0;
    };
    $scope.areAllSelected = function() {
      return $scope.selected.browserIDs.length === Object.keys($scope.browserList).length;
    };
    $scope.rename = function() {
      var browserID, _i, _len, _ref, _results;
      _ref = $scope.selected.browserIDs;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        browserID = _ref[_i];
        _results.push($scope.browserList[browserID].editing = true);
      }
      return _results;
    };
    return $scope.clickRename = function(browserID) {
      var browser;
      browser = $scope.browserList[browserID];
      if (isOwner(browser, {
        email: $scope.email,
        ns: namespace
      })) {
        return browser.editing = true;
      }
    };
  });

  CBLandingPage.filter("removeSlash", function() {
    return function(input) {
      var mps;
      mps = input.split('/');
      return mps[mps.length - 1];
    };
  });

  CBLandingPage.filter("isNotEmpty", function() {
    return function(input) {
      if (!input) {
        return false;
      } else {
        return Object.keys(input).length;
      }
    };
  });

}).call(this);
