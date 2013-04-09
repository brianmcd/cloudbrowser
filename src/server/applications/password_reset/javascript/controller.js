(function() {
  var CBPasswordReset, CloudBrowserDb;

  CBPasswordReset = angular.module("CBPasswordReset", []);

  CloudBrowserDb = server.db;

  CBPasswordReset.controller("ResetCtrl", function($scope) {
    var query, username;
    query = Utils.searchStringtoJSON(location.search);
    username = query['user'].split("@")[0];
    $scope.username = username.charAt(0).toUpperCase() + username.slice(1);
    $scope.password = null;
    $scope.vpassword = null;
    $scope.isDisabled = false;
    $scope.password_error = null;
    $scope.password_success = null;
    $scope.$watch("password", function() {
      $scope.password_error = null;
      $scope.password_success = null;
      return $scope.isDisabled = false;
    });
    $scope.reset = function() {
      var password, token;
      $scope.isDisabled = true;
      username = query['user'];
      token = query['token'];
      password = $scope.password;
      if (!(password != null) || !/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\da-zA-Z])\S{8,15}$/.test(password)) {
        return $scope.password_error = "Password must be have a length between 8 - 15 characters, must contain atleast 1 uppercase, 1 lowercase, 1 digit and 1 special character. Spaces are not allowed.";
      } else {
        return CloudBrowserDb.collection("users", function(err, collection) {
          if (!err) {
            return collection.findOne({
              email: username
            }, function(err, user) {
              if (user && user.status === "reset_password" && user.token === token) {
                return collection.update({
                  email: username
                }, {
                  $unset: {
                    token: "",
                    status: ""
                  }
                }, {
                  w: 1
                }, function(err, result) {
                  if (err) {
                    throw err;
                  } else {
                    return HashPassword({
                      password: password
                    }, function(result) {
                      return collection.update({
                        email: username
                      }, {
                        $set: {
                          key: result.key.toString('hex'),
                          salt: result.salt.toString('hex')
                        }
                      }, function(err, result) {
                        if (err) {
                          throw err;
                        } else {
                          return $scope.$apply(function() {
                            return $scope.password_success = "The password has been successfully reset";
                          });
                        }
                      });
                    });
                  }
                });
              } else {
                return $scope.$apply(function() {
                  return $scope.password_error = "Invalid reset request";
                });
              }
            });
          } else {
            throw err;
          }
        });
      }
    };
    return $scope.isDisabled = false;
  });

}).call(this);
