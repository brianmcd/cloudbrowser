(function() {
  var CBLandingPage, cb;

  cb = {};

  cb.currentVirtualBrowser = cloudbrowser.getCurrentVirtualBrowser();

  cb.appConfig = cb.currentVirtualBrowser.getAppConfig();

  cb.util = cloudbrowser.getUtil();

  CBLandingPage = angular.module("CBLandingPage", []);

  CBLandingPage.controller("UserCtrl", function($scope, $timeout) {
    var addCollaborator, checkPermission, grantPerm, months, selected, sendMail, toggleEnabledDisabled, utils, vbMgr;
    $scope.user = cb.currentVirtualBrowser.getCreator();
    $scope.description = cb.appConfig.getDescription();
    $scope.mountPoint = cb.appConfig.getMountPoint();
    $scope.isDisabled = {
      open: true,
      share: true,
      del: true,
      rename: true
    };
    $scope.virtualBrowserList = [];
    $scope.selected = [];
    $scope.addingReaderWriter = false;
    $scope.confirmDelete = false;
    $scope.addingOwner = false;
    $scope.predicate = 'dateCreated';
    $scope.reverse = true;
    $scope.filterType = 'all';
    $scope.safeApply = function(fn) {
      var phase;
      phase = this.$root.$$phase;
      if (phase === '$apply' || phase === '$digest') {
        if (fn) return fn();
      } else {
        return this.$apply(fn);
      }
    };
    months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    utils = {
      formatDate: function(date) {
        var day, hours, minutes, month, time, timeSuffix, year;
        if (!date) return null;
        month = months[date.getMonth()];
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
      }
    };
    vbMgr = {
      find: function(id) {
        var vb;
        vb = $.grep($scope.virtualBrowserList, function(element, index) {
          return element.id === id;
        });
        return vb[0];
      },
      add: function(vb) {
        if (!this.find(vb.id)) {
          vb.dateCreated = utils.formatDate(vb.dateCreated);
          vb.addEventListener('Shared', function(err) {
            if (err) {
              return console.log(err);
            } else {
              vb.getOwners(function(owners) {
                return $scope.safeApply(function() {
                  return vb.owners = owners;
                });
              });
              return vb.getReaderWriters(function(readersWriters) {
                return $scope.safeApply(function() {
                  return vb.collaborators = readersWriters;
                });
              });
            }
          });
          vb.addEventListener('Renamed', function(err, name) {
            if (!err) {
              return $scope.safeApply(function() {
                return vb.name = name;
              });
            } else {
              return console.log(err);
            }
          });
          return $scope.safeApply(function() {
            return $scope.virtualBrowserList.push(vb);
          });
        }
      },
      remove: function(id) {
        return $scope.safeApply(function() {
          var oldLength;
          oldLength = $scope.virtualBrowserList.length;
          $scope.virtualBrowserList = $.grep($scope.virtualBrowserList, function(element, index) {
            return element.id !== id;
          });
          if (oldLength > $scope.virtualBrowserList.length) {
            return selected.remove(id);
          }
        });
      }
    };
    selected = {
      add: function(id) {
        if ($scope.selected.indexOf(id) === -1) return $scope.selected.push(id);
      },
      remove: function(id) {
        if ($scope.selected.indexOf(id) !== -1) {
          return $scope.selected.splice($scope.selected.indexOf(id), 1);
        }
      }
    };
    checkPermission = function(type, callback) {
      var id, outstanding, _i, _len, _ref;
      outstanding = $scope.selected.length;
      _ref = $scope.selected;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        id = _ref[_i];
        vbMgr.find(id).checkPermissions(type, function(hasPermission) {
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
    toggleEnabledDisabled = function(newValue, oldValue) {
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
    cb.appConfig.getVirtualBrowsers(function(virtualBrowsers) {
      var vb, _i, _len, _results;
      _results = [];
      for (_i = 0, _len = virtualBrowsers.length; _i < _len; _i++) {
        vb = virtualBrowsers[_i];
        _results.push(vbMgr.add(vb));
      }
      return _results;
    });
    cb.appConfig.addEventListener('Added', function(vb) {
      return vbMgr.add(vb);
    });
    cb.appConfig.addEventListener('Removed', function(id) {
      return vbMgr.remove(id);
    });
    $scope.$watch('selected.length', function(newValue, oldValue) {
      toggleEnabledDisabled(newValue, oldValue);
      $scope.addingReaderWriter = false;
      return $scope.addingOwner = false;
    });
    $scope.createVB = function() {
      return cb.appConfig.createVirtualBrowser(function(err) {
        if (err) {
          return $scope.safeApply(function() {
            return $scope.error = err.message;
          });
        }
      });
    };
    $scope.logout = function() {
      return cb.appConfig.logout();
    };
    $scope.open = function() {
      var id, openNewTab, _i, _len, _ref, _results;
      openNewTab = function(id) {
        var url, win;
        url = cb.appConfig.getUrl() + "/browsers/" + id + "/index";
        win = window.open(url, '_blank');
      };
      _ref = $scope.selected;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        id = _ref[_i];
        _results.push(openNewTab(id));
      }
      return _results;
    };
    $scope.remove = function() {
      while ($scope.selected.length > 0) {
        vbMgr.find($scope.selected[0]).close(function(err) {
          if (err) {
            return $scope.error = "You do not have the permission to perform this action";
          }
        });
      }
      return $scope.confirmDelete = false;
    };
    sendMail = function(email) {
      var msg, subject;
      subject = "CloudBrowser - " + ($scope.user.getEmail()) + " shared an vb with you.";
      msg = ("Hi " + email + "<br>To view the vb, visit <a href='" + (cb.appConfig.getUrl()) + "'>") + ("" + $scope.mountPoint + "</a> and login to your existing account or use your google ID to login if") + " you do not have an account already.";
      return cb.util.sendEmail(email, subject, msg, function() {});
    };
    grantPerm = function(user, perm, callback) {
      var id, vb, _i, _len, _ref, _results;
      _ref = $scope.selected;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        id = _ref[_i];
        vb = vbMgr.find(id);
        _results.push((function(vb) {
          return vb.isOwner($scope.user, function(isOwner) {
            if (isOwner) {
              return vb.grantPermissions(perm, user, function(err) {
                if (!err) {
                  sendMail(user.getEmail());
                  return callback(user);
                } else {
                  return $scope.safeApply(function() {
                    return $scope.error = err;
                  });
                }
              });
            } else {
              return $scope.safeApply(function() {
                return $scope.error = "You do not have the permission to perform this action.";
              });
            }
          });
        })(vb));
      }
      return _results;
    };
    addCollaborator = function(selectedUser, perm, callback) {
      var emailID, lParIdx, namespace, rParIdx, user;
      lParIdx = selectedUser.indexOf("(");
      rParIdx = selectedUser.indexOf(")");
      if (lParIdx !== -1 && rParIdx !== -1) {
        emailID = selectedUser.substring(0, lParIdx - 1);
        namespace = selectedUser.substring(lParIdx + 1, rParIdx);
        user = new cloudbrowser.app.User(emailID, namespace);
        return cb.appConfig.isUserRegistered(user, function(exists) {
          if (exists) {
            return grantPerm(user, perm, callback);
          } else {
            return $scope.safeApply(function() {
              return $scope.error = "Invalid Collaborator Selected";
            });
          }
        });
      } else if (lParIdx === -1 && rParIdx === -1 && /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test(selectedUser.toUpperCase())) {
        user = new cloudbrowser.app.User(selectedUser, "google");
        return grantPerm(user, perm, callback);
      } else {
        return $scope.error = "Invalid Collaborator Selected";
      }
    };
    $scope.openAddReaderWriterForm = function() {
      $scope.addingReaderWriter = !$scope.addingReaderWriter;
      if ($scope.addingReaderWriter) return $scope.addingOwner = false;
    };
    $scope.addReaderWriter = function() {
      return addCollaborator($scope.selectedReaderWriter, {
        readwrite: true
      }, function(user) {
        return $scope.safeApply(function() {
          $scope.boxMessage = "The selected virtual browsers are now shared with " + user.getEmail() + " (" + user.getNameSpace() + ")";
          $scope.addingReaderWriter = false;
          return $scope.selectedReaderWriter = null;
        });
      });
    };
    $scope.openAddOwnerForm = function() {
      $scope.addingOwner = !$scope.addingOwner;
      if ($scope.addingOwner) return $scope.addingReaderWriter = false;
    };
    $scope.addOwner = function() {
      return addCollaborator($scope.selectedOwner, {
        own: true,
        remove: true,
        readwrite: true
      }, function(user) {
        return $scope.safeApply(function() {
          $scope.boxMessage = "The selected virtualBrowsers are now shared with " + user.getEmail() + " (" + user.getNameSpace() + ")";
          $scope.addingOwner = false;
          return $scope.selectedOwner = null;
        });
      });
    };
    $scope.select = function($event, id) {
      var checkbox;
      checkbox = $event.target;
      if (checkbox.checked) {
        return selected.add(id);
      } else {
        return selected.remove(id);
      }
    };
    $scope.selectAll = function($event) {
      var action, checkbox, vb, _i, _len, _ref, _results;
      checkbox = $event.target;
      action = checkbox.checked ? selected.add : selected.remove;
      _ref = $scope.virtualBrowserList;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        vb = _ref[_i];
        _results.push(action(vb.id));
      }
      return _results;
    };
    $scope.getSelectedClass = function(id) {
      if ($scope.isSelected(id)) {
        return 'highlight';
      } else {
        return '';
      }
    };
    $scope.isSelected = function(id) {
      return $scope.selected.indexOf(id) >= 0;
    };
    $scope.areAllSelected = function() {
      return $scope.selected.length === $scope.virtualBrowserList.length;
    };
    $scope.rename = function() {
      var id, _i, _len, _ref, _results;
      _ref = $scope.selected;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        id = _ref[_i];
        _results.push(vbMgr.find(id).editing = true);
      }
      return _results;
    };
    return $scope.clickRename = function(id) {
      var vb;
      vb = vbMgr.find(id);
      return vb.isOwner($scope.user, function(isOwner) {
        if (isOwner) {
          return $scope.safeApply(function() {
            return vb.editing = true;
          });
        }
      });
    };
  });

  CBLandingPage.filter("removeSlash", function() {
    return function(input) {
      var mps;
      mps = input.split('/');
      return mps[mps.length - 1];
    };
  });

  CBLandingPage.filter("virtualBrowserFilter", function() {
    var _this = this;
    return function(list, arg) {
      var filterType, modifiedList, user, vb, _fn, _fn2, _fn3, _fn4, _i, _j, _k, _l, _len, _len2, _len3, _len4;
      filterType = arg.type;
      user = arg.user;
      modifiedList = [];
      if (filterType === 'owned') {
        _fn = function(vb) {
          return vb.isOwner(user, function(isOwner) {
            if (isOwner) return modifiedList.push(vb);
          });
        };
        for (_i = 0, _len = list.length; _i < _len; _i++) {
          vb = list[_i];
          _fn(vb);
        }
      }
      if (filterType === 'notOwned') {
        _fn2 = function(vb) {
          return vb.isOwner(user, function(isOwner) {
            if (!isOwner) return modifiedList.push(vb);
          });
        };
        for (_j = 0, _len2 = list.length; _j < _len2; _j++) {
          vb = list[_j];
          _fn2(vb);
        }
      }
      if (filterType === 'shared') {
        _fn3 = function(vb) {
          return vb.getNumReaderWriters(function(numReaderWriters) {
            if (numReaderWriters) {
              return modifiedList.push(vb);
            } else {
              return vb.getNumOwners(function(numOwners) {
                if (numOwners > 1) return modifiedList.push(vb);
              });
            }
          });
        };
        for (_k = 0, _len3 = list.length; _k < _len3; _k++) {
          vb = list[_k];
          _fn3(vb);
        }
      }
      if (filterType === 'notShared') {
        _fn4 = function(vb) {
          return vb.getNumOwners(function(numOwners) {
            if (numOwners === 1) {
              return vb.getNumReaderWriters(function(numReaderWriters) {
                if (!numReaderWriters) return modifiedList.push(vb);
              });
            }
          });
        };
        for (_l = 0, _len4 = list.length; _l < _len4; _l++) {
          vb = list[_l];
          _fn4(vb);
        }
      }
      if (filterType === 'all') modifiedList = list;
      return modifiedList;
    };
  });

  CBLandingPage.directive('ngHasfocus', function() {
    return function(scope, element, attrs) {
      scope.$watch(attrs.ngHasfocus, function(nVal, oVal) {
        if (nVal) return element[0].focus();
      });
      element.bind('blur', function() {
        return scope.$apply(attrs.ngHasfocus + " = false");
      });
      return element.bind('keydown', function(e) {
        if (e.which === 13) return scope.$apply(attrs.ngHasfocus + " = false");
      });
    };
  });

  CBLandingPage.directive('typeahead', function() {
    var directive;
    return directive = {
      restrict: 'A',
      link: function(scope, element, attrs) {
        var args;
        args = {
          source: function(query, process) {
            var data;
            data = [];
            return cb.appConfig.getUsers(function(users) {
              var collaborator, id, index, user, vb, _i, _j, _len, _len2, _ref;
              _ref = scope.selected;
              for (_i = 0, _len = _ref.length; _i < _len; _i++) {
                id = _ref[_i];
                vb = $.grep(scope.virtualBrowserList, function(element, index) {
                  return element.id === id;
                });
                vb = vb[0];
                index = 0;
                if (attrs.typeahead === "selectedReaderWriter") {
                  while (index < users.length) {
                    user = users[index];
                    (function(user) {
                      return vb.isOwner(user, function(isOwner) {
                        if (isOwner) {
                          return scope.safeApply(function() {
                            return users.splice(index, 1);
                          });
                        } else {
                          return vb.isReaderWriter(user, function(isReaderWriter) {
                            return scope.safeApply(function() {
                              if (isReaderWriter) {
                                return users.splice(index, 1);
                              } else {
                                return index++;
                              }
                            });
                          });
                        }
                      });
                    })(user);
                  }
                } else if (attrs.typeahead === "selectedOwner") {
                  while (index < users.length) {
                    user = users[index];
                    (function(user) {
                      return vb.isOwner(user, function(isOwner) {
                        return scope.safeApply(function() {
                          if (isOwner) {
                            return users.splice(index, 1);
                          } else {
                            return index++;
                          }
                        });
                      });
                    })(user);
                  }
                }
              }
              for (_j = 0, _len2 = users.length; _j < _len2; _j++) {
                collaborator = users[_j];
                data.push(collaborator.getEmail() + ' (' + collaborator.getNameSpace() + ')');
              }
              return process(data);
            });
          },
          updater: function(item) {
            scope.$apply(attrs.typeahead + (" = '" + item + "'"));
            return item;
          }
        };
        return $(element).typeahead(args);
      }
    };
  });

}).call(this);
