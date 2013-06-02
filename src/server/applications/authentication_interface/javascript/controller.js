(function() {
  var CBAuthentication;

  CBAuthentication = angular.module("CBAuthentication", []);

  CBAuthentication.controller("LoginCtrl", function($scope) {
    $scope.email = null;
    $scope.password = null;
    $scope.emailError = null;
    $scope.loginError = null;
    $scope.resetSuccessMsg = null;
    $scope.isDisabled = false;
    $scope.showEmailButton = false;
    $scope.$watch("email + password", function() {
      $scope.loginError = null;
      $scope.isDisabled = false;
      return $scope.resetSuccessMsg = null;
    });
    $scope.$watch("email", function() {
      return $scope.emailError = null;
    });
    $scope.googleLogin = function() {
      return CloudBrowser.auth.googleLogin(location.search);
    };
    $scope.login = function() {
      if (!$scope.email || !$scope.password) {
        return $scope.loginError = "Please provide both the Email ID and the password to login";
      } else {
        $scope.isDisabled = true;
        return CloudBrowser.auth.login(CloudBrowser.User($scope.email, 'local'), $scope.password, location.search, function(success) {
          if (!success) {
            $scope.$apply(function() {
              return $scope.loginError = "Invalid Credentials";
            });
          }
          return $scope.isDisabled = false;
        });
      }
    };
    return $scope.sendResetLink = function() {
      if (!($scope.email != null) || !/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test($scope.email.toUpperCase())) {
        return $scope.emailError = "Please provide a valid email ID";
      } else {
        $scope.resetDisabled = true;
        return CloudBrowser.auth.sendResetLink(CloudBrowser.User($scope.email, 'local'), function(success) {
          if (success) {
            $scope.resetSuccessMsg = "A password reset link has been sent to your email ID.";
          } else {
            $scope.$apply(function() {
              return $scope.emailError = "This email ID is not registered with us.";
            });
          }
          return $scope.$apply(function() {
            return $scope.resetDisabled = false;
          });
        });
      }
    };
  });

  CBAuthentication.controller("SignupCtrl", function($scope) {
    $scope.email = null;
    $scope.password = null;
    $scope.vpassword = null;
    $scope.emailError = null;
    $scope.signupError = null;
    $scope.passwordError = null;
    $scope.successMessage = false;
    $scope.isDisabled = false;
    $scope.$watch("email", function(nval, oval) {
      $scope.emailError = null;
      $scope.signupError = null;
      $scope.isDisabled = false;
      $scope.successMessage = false;
      return CloudBrowser.app.userExists(CloudBrowser.User($scope.email, 'local'), function(exists) {
        if (exists) {
          return $scope.$apply(function() {
            $scope.emailError = "Account with this Email ID already exists!";
            return $scope.isDisabled = true;
          });
        }
      });
    });
    $scope.$watch("password+vpassword", function() {
      $scope.signupError = null;
      $scope.passwordError = null;
      return $scope.isDisabled = false;
    });
    $scope.googleLogin = function() {
      return CloudBrowser.auth.googleLogin(location.search);
    };
    return $scope.signup = function() {
      $scope.isDisabled = true;
      if (!($scope.email != null) || !($scope.password != null)) {
        return $scope.signupError = "Must provide both Email and Password!";
      } else if (!/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test($scope.email.toUpperCase())) {
        return $scope.emailError = "Not a valid Email ID!";
      } else if (!/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\da-zA-Z])\S{8,15}$/.test($scope.password)) {
        return $scope.passwordError = "Password must be have a length between 8 - 15 characters," + " must contain atleast 1 uppercase, 1 lowercase, 1 digit and 1 special character." + " Spaces are not allowed.";
      } else {
        return CloudBrowser.auth.signup(CloudBrowser.User($scope.email, 'local'), $scope.password, function() {
          return $scope.$apply(function() {
            return $scope.successMessage = true;
          });
        });
      }
    };
  });

}).call(this);
