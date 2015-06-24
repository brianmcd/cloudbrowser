function ChatRoom(){
    this.messages = [];
    this.currentUser = null;
}

var app = angular.module("Chat4", []);

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
    $scope.version = 0;
    $scope.messages = [];
    $scope.userName = "Goose_" + __userId;
    $scope.editingUserName = false;
    $scope.alertMessages = [];
    var safeApply = function() {
      if ($rootScope.$$phase === '$apply' || $rootScope.$$phase === '$digest') {
        return;
      }
      return $rootScope.$apply(angular.noop);
    };

    function discardOldMessages(){
        if ($scope.messages.length >= 100) {
            $scope.messages.splice(0, 50);
        }
    }

    //TODO wrap socket.on with safeApply
    var socket = io.connect("http://" + window.location.host + '/chat');

    socket.on('sync', function(data){
        for (var i = 0; i < data.messages.length; i++) {
            var msg = data.messages[i];
            if (msg.version > $scope.version) {
                $scope.messages.push(msg);
            }
        }
        $scope.version = data.version;
        discardOldMessages();
        safeApply();
    });

    socket.emit('join', {
        chatRoomId : __chatRoomId,
        userId : __userId,
        userName : $scope.userName,
        version : $scope.version
    });
    
    function scrollDown() {
      var messageBox;
      messageBox = document.getElementById("chatMessageBox");
      return messageBox.scrollTop = messageBox.scrollHeight;
    }

    $scope.alert = function(msg) {
        var alert = {
            msg: msg
        };
        $scope.alertMessages.push(alert);
        $timeout(function() {
            $scope.removeAlert(alert);
        }, 3000);
    };
    $scope.removeAlert = function(alert) {
      var index = $scope.alertMessages.indexOf(alert);
      if (index >= 0) {
        return $scope.alertMessages.splice(index, 1);
      }
    };

    function postMsg(msg){
        var msgObj = {
            msg: msg,
            userName: $scope.userName,
            time: Date.now()
        };
        socket.emit('message', msgObj);
        //TODO should check if the emit is successful or not
        $scope.messages.push(msgObj);
        discardOldMessages();
    }
    
    $scope.changeName = function() {
        if (!$scope.draftUserName || $scope.draftUserName === '') {
            return $scope.alert("The user name must not be empty.");
        }
        var name = $scope.draftUserName.trim();
        if (name === '') {
            return $scope.alert("The user name must not be empty.");
        }
        if (name === $scope.userName) {
            $scope.editingUserName = false;
            return;
        }
        //TODO check for existence
        // $scope.alert("There is already a user called " + name);
        postMsg( $scope.userName + " is now " + name, "sys");
        $scope.userName = name;
        $scope.editingUserName = false;
    };

    $scope.postMessage = function() {
        postMsg($scope.currentMessage);
        $scope.currentMessage = '';
    };

    $scope.getMsgClass = function(msg) {
      if (msg.type === 'sys') {
        return "alert alert-success";
      }
      return "";
    };
});
