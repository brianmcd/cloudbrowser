// Generated by CoffeeScript 1.8.0
(function() {
  var app;

  app = angular.module("Chat4", []);

  app.directive('enterSubmit', function() {
    var directive;
    return directive = {
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
    var addMessage, browserId, chatManager, checkUpdate, checkUpdateInterval, currentBrowser, eventbus, messageId, newMessageHandler, newMessageVersion, safeApply, scrollDown;
    currentBrowser = cloudbrowser.currentBrowser;
    browserId = currentBrowser.getID();
    chatManager = cloudbrowser.currentAppInstanceConfig.getObj();
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
    eventbus = cloudbrowser.currentAppInstanceConfig.getEventBus();
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
      msgObj = {
        browserId: browserId,
        msg: msg,
        userName: $scope.userName,
        time: Date.now(),
        $$hashKey: "" + browserId + "_" + (messageId++)
      };
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
      return $scope.currentMessage = '';
    };
    return $scope.getMsgClass = function(msg) {
      if (msg.type === 'sys') {
        return "alert alert-success";
      }
      return "";
    };
  });

}).call(this);
