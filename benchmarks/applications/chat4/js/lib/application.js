// Generated by CoffeeScript 1.8.0
(function() {
  var app, dateFormatCache;

  dateFormatCache = {
    capacity: 200,
    evicationSize: 100,
    keys: [],
    cache: {},
    getKey: function(val, format) {
      if (angular.isDate(val)) {
        return val.getTime() + ("_" + format);
      }
      return val + ("_" + format);
    },
    get: function(input, format) {
      var key;
      key = this.getKey(input, format);
      return this.cache[key];
    },
    put: function(input, format, val) {
      var deleted, i, key, _i, _len;
      key = this.getKey(input, format);
      if (this.cache[key] != null) {
        this.cache[key] = val;
        return;
      }
      if (this.keys.length >= this.capacity) {
        deleted = this.keys.splice(0, this.evicationSize);
        for (_i = 0, _len = deleted.length; _i < _len; _i++) {
          i = deleted[_i];
          delete this.cache[i];
        }
      }
      this.keys.push(key);
      this.cache[key] = val;
    }
  };

  angular.module('utilService', []).filter('mydate', [
    'dateFilter', function($filter) {
      return function(input, format) {
        var cached;
        cached = dateFormatCache.get(input, format);
        if (typeof chached === "undefined" || chached === null) {
          cached = $filter(input, format);
          dateFormatCache.put(input, format, cached);
        }
        return cached;
      };
    }
  ]);

  app = angular.module("Chat4", ['utilService']);

  app.directive('enterSubmit', function() {
    return {
      restrict: 'A',
      link: function(scope, element, attrs) {
        return element.bind('keydown', function(e) {
          if (e.which === 13) {
            scope.$apply(function() {
              return scope.$eval(attrs.enterSubmit);
            });
            return e.preventDefault();
          }
        });
      }
    };
  });

  app.controller("ChatCtrl", function($scope, $timeout, $rootScope) {
    var addMessage, appInstance, browserId, chatManager, checkUpdate, checkUpdateInterval, currentBrowser, eventbus, messageId, newMessageHandler, newMessageVersion, safeApply, scrollDown;
    currentBrowser = cloudbrowser.currentBrowser;
    browserId = currentBrowser.getID();
    appInstance = cloudbrowser.currentAppInstanceConfig;
    chatManager = appInstance.getObj();
    messageId = 0;
    checkUpdateInterval = 0;
    newMessageVersion = null;
    $scope.userName = "Goose_" + browserId;
    $scope.editingUserName = false;
    $scope.alertMessages = [];
    chatManager.users[browserId] = $scope.userName;
    $scope.chatManager = chatManager;
    safeApply = function() {
      if ($rootScope.$$phase === '$apply' || $rootScope.$$phase === '$digest') {
        return;
      }
      return $rootScope.$apply(angular.noop);
    };
    newMessageHandler = function(fromBrowser, version) {
      if (version < chatManager.getVersion()) {
        return;
      }
      if (fromBrowser === browserId) {
        return;
      }
      if (checkUpdateInterval > 0) {
        newMessageVersion = version;
        return;
      }
      return safeApply();
    };
    checkUpdate = function() {
      if ((newMessageVersion == null) || newMessageVersion < chatManager.getVersion()) {
        return;
      }
      newMessageVersion = null;
      return safeApply();
    };
    if (checkUpdateInterval > 0) {
      setInterval(checkUpdate, checkUpdateInterval);
    }
    eventbus = appInstance.getEventBus();
    eventbus.on('newMessage', function(fromBrowser, version) {
      return setImmediate(newMessageHandler, fromBrowser, version);
    });
    scrollDown = function() {
      var messageBox;
      messageBox = document.getElementById("chatMessageBox");
      return messageBox.scrollTop = messageBox.scrollHeight;
    };
    $scope.alert = function(msg) {
      var alert;
      alert = {
        msg: msg
      };
      $scope.alertMessages.push(alert);
      return $timeout(function() {
        return $scope.removeAlert(alert);
      }, 3000);
    };
    $scope.removeAlert = function(alert) {
      var index;
      index = $scope.alertMessages.indexOf(alert);
      if (index >= 0) {
        return $scope.alertMessages.splice(index, 1);
      }
    };
    addMessage = function(msg, type) {
      var msgObj, version;
      msgObj = currentBrowser.createSharedObject({
        msg: msg,
        userName: $scope.userName,
        time: Date.now()
      });
      if (type != null) {
        msgObj.type = type;
      }
      version = chatManager.addMessage(msgObj);
      return eventbus.emit('newMessage', browserId, version);
    };
    $scope.changeName = function() {
      var k, name, v, _ref;
      if (!$scope.draftUserName || $scope.draftUserName === '') {
        return $scope.alert("The user name must not be empty.");
      }
      name = $scope.draftUserName.trim();
      if (name === '') {
        return $scope.alert("The user name must not be empty.");
      }
      if (name === $scope.userName) {
        $scope.editingUserName = false;
        return;
      }
      _ref = chatManager.users;
      for (k in _ref) {
        v = _ref[k];
        if (k !== browserId && v.toLowerCase() === name.toLowerCase()) {
          return $scope.alert("There is already a user called " + name);
        }
      }
      addMessage("" + $scope.userName + " is now " + name, "sys");
      $scope.userName = name;
      chatManager.users[browserId] = $scope.userName;
      return $scope.editingUserName = false;
    };
    $scope.postMessage = function() {
      addMessage($scope.currentMessage);
      $scope.currentMessage = '';
    };
    return $scope.getMsgClass = function(msg) {
      if (msg.type === 'sys') {
        return "alert alert-success";
      }
      return "";
    };
  });

}).call(this);
