(function() {
  var CBPasswordReset, query;

  CBPasswordReset = angular.module("CBPasswordReset", []);

  query = Utils.searchStringtoJSON(location.search);

  CBPasswordReset.controller("ResetCtrl", function($scope) {
    var email;
    email = query['user'].split("@")[0];
    $scope.email = email.charAt(0).toUpperCase() + email.slice(1);
    $scope.password = null;
    $scope.vpassword = null;
    $scope.isDisabled = false;
    $scope.passwordError = null;
    $scope.passwordSuccess = null;
    $scope.$watch("password", function() {
      $scope.passwordError = null;
      $scope.passwordSuccess = null;
      return $scope.isDisabled = false;
    });
    return $scope.reset = function() {
      var token;
      $scope.isDisabled = true;
      email = query['user'];
      token = query['token'];
      if (!($scope.password != null) || !/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\da-zA-Z])\S{8,15}$/.test($scope.password)) {
        return $scope.passwordError = "Password must be have a length between 8 - 15 characters," + " must contain atleast 1 uppercase, 1 lowercase, 1 digit and 1 special character." + " Spaces are not allowed.";
      } else {
        return CloudBrowser.app.resetPassword({
          email: query['user'],
          ns: 'local'
        }, $scope.password, token, function(success) {
          $scope.$apply(function() {
            if (success) {
              return $scope.passwordSuccess = "The password has been successfully reset";
            } else {
              return $scope.passwordError = "Password can not be changed as the link has expired.";
            }
          });
          return $scope.isDisabled = false;
        });
      }
    };
  });

}).call(this);
