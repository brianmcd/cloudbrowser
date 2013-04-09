(function() {
  var CBAuthentication, CloudBrowserDb, baseURL, googleLogin, mongoStore, mountPoint, rootURL;

  CBAuthentication = angular.module("CBAuthentication", []);

  CloudBrowserDb = server.db;

  mongoStore = server.mongoStore;

  mountPoint = Utils.getAppMountPoint(bserver.mountPoint, "authenticate");

  rootURL = "http://" + server.config.domain + ":" + server.config.port;

  baseURL = rootURL + mountPoint;

  googleLogin = function() {
    var query, search;
    search = location.search;
    query = Utils.searchStringtoJSON(search);
    if (search[0] === "?") {
      search += "&mountPoint=" + mountPoint;
    } else {
      search = "?mountPoint=" + mountPoint;
    }
    if (!(query.redirectto != null)) search += "&redirectto=" + mountPoint;
    return bserver.redirect(rootURL + '/googleAuth' + search);
  };

  CBAuthentication.controller("LoginCtrl", function($scope) {
    $scope.email = null;
    $scope.password = null;
    $scope.email_error = null;
    $scope.login_error = null;
    $scope.reset_success_msg = null;
    $scope.isDisabled = false;
    $scope.show_email_button = false;
    $scope.login = function() {
      if (!($scope.email != null) || !($scope.password != null)) {
        return $scope.login_error = "Please provide both the Email ID and the password to login";
      } else {
        $scope.isDisabled = true;
        CloudBrowserDb.collection("users", function(err, collection) {
          if (err) throw err;
          return collection.findOne({
            email: $scope.email
          }, function(err, user) {
            if (user && user.status !== 'unverified') {
              return HashPassword({
                password: $scope.password,
                salt: new Buffer(user.salt, 'hex')
              }, function(result) {
                var sessionID;
                if (result.key.toString('hex') === user.key) {
                  sessionID = decodeURIComponent(bserver.getSessions()[0]);
                  return mongoStore.get(sessionID, function(err, session) {
                    if (err) {
                      throw new Error("Error in finding the session:" + sessionID + " Error:" + err);
                    } else {
                      if (!(session.user != null)) {
                        session.user = [
                          {
                            app: mountPoint,
                            email: $scope.email
                          }
                        ];
                      } else {
                        session.user.push({
                          app: mountPoint,
                          email: $scope.email
                        });
                      }
                      /* Remember me
                      if $scope.remember
                          session.cookie.maxAge = 24 * 60 * 60 * 1000
                          #notify the client
                          bserver.updateCookie(session.cookie.maxAge)
                      else
                          session.cookie.expires = false
                      */
                      return mongoStore.set(sessionID, session, function() {
                        var query;
                        query = Utils.searchStringtoJSON(location.search);
                        if (query.redirectto != null) {
                          return bserver.redirect(rootURL + query.redirectto);
                        } else {
                          return bserver.redirect(baseURL);
                        }
                      });
                    }
                  });
                } else {
                  return $scope.$apply(function() {
                    return $scope.login_error = "Invalid Credentials";
                  });
                }
              });
            } else {
              return $scope.$apply(function() {
                return $scope.login_error = "Invalid Credentials";
              });
            }
          });
        });
        return $scope.isDisabled = false;
      }
    };
    $scope.googleLogin = googleLogin;
    $scope.$watch("email + password", function() {
      $scope.login_error = null;
      $scope.isDisabled = false;
      return $scope.reset_success_msg = null;
    });
    $scope.$watch("email", function() {
      return $scope.email_error = null;
    });
    return $scope.sendResetLink = function() {
      if (!($scope.email != null) || !/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test($scope.email.toUpperCase())) {
        return $scope.email_error = "Please provide a valid email ID";
      } else {
        return CloudBrowserDb.collection("users", function(err, collection) {
          if (err) throw err;
          return collection.findOne({
            email: $scope.email
          }, function(err, user) {
            if (err) throw err;
            if (!user) {
              return $scope.$apply(function() {
                return $scope.email_error = "This email ID is not registered with us.";
              });
            } else {
              $scope.$apply(function() {
                return $scope.resetDisabled = true;
              });
              return Crypto.randomBytes(32, function(err, buf) {
                var esc_email, message, subject;
                if (err) callback(err, null);
                buf = buf.toString('hex');
                esc_email = encodeURIComponent($scope.email);
                subject = "Link to reset your CloudBrowser password";
                message = "You have requested to change your password. If you want to continue click <a href='" + baseURL + "/password_reset?token=" + buf + "&user=" + esc_email + "'>reset</a>. If you have not requested a change in password then take no action.";
                return sendEmail($scope.email, subject, message, function(err) {
                  $scope.$apply(function() {
                    $scope.resetDisabled = false;
                    return $scope.reset_success_msg = "A password reset link has been sent to your email ID.";
                  });
                  return collection.update({
                    email: user.email
                  }, {
                    $set: {
                      status: "reset_password",
                      token: buf
                    }
                  }, {
                    w: 1
                  }, function(err, result) {
                    if (err) throw err;
                  });
                });
              });
            }
          });
        });
      }
    };
  });

  CBAuthentication.controller("SignupCtrl", function($scope) {
    $scope.email = null;
    $scope.password = null;
    $scope.vpassword = null;
    $scope.email_error = null;
    $scope.signup_error = null;
    $scope.password_error = null;
    $scope.success_message = false;
    $scope.isDisabled = false;
    $scope.$watch("email", function(nval, oval) {
      $scope.email_error = null;
      $scope.signup_error = null;
      $scope.isDisabled = false;
      $scope.success_message = false;
      return CloudBrowserDb.collection("users", function(err, collection) {
        if (err) throw err;
        return collection.findOne({
          email: nval
        }, function(err, item) {
          if (item) {
            return $scope.$apply(function() {
              $scope.email_error = "Account with this Email ID already exists!";
              return $scope.isDisabled = true;
            });
          }
        });
      });
    });
    $scope.$watch("password+vpassword", function() {
      $scope.signup_error = null;
      $scope.password_error = null;
      return $scope.isDisabled = false;
    });
    $scope.signup = function() {
      $scope.isDisabled = true;
      if (!($scope.email != null) || !($scope.password != null)) {
        return $scope.signup_error = "Must provide both Email and Password!";
      } else if (!/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test($scope.email.toUpperCase())) {
        return $scope.email_error = "Not a valid Email ID!";
      } else if (!/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\da-zA-Z])\S{8,15}$/.test($scope.password)) {
        return $scope.password_error = "Password must be have a length between 8 - 15 characters, must contain atleast 1 uppercase, 1 lowercase, 1 digit and 1 special character. Spaces are not allowed.";
      } else {
        return Crypto.randomBytes(32, function(err, buf) {
          var confirmationMsg, subject;
          if (err) callback(err, null);
          buf = buf.toString('hex');
          subject = "Activate your cloudbrowser account";
          confirmationMsg = "Please click on the link below to verify your email address.<br>" + ("<p><a href='" + baseURL + "/activate/" + buf + "'>Activate your account</a></p>") + "<p>If you have received this message in error and did not sign up for a cloudbrowser account," + (" click <a href='" + baseURL + "/deactivate/" + buf + "'>not my account</a></p>");
          return sendEmail($scope.email, subject, confirmationMsg, function(err) {
            if (err) {
              throw err;
              return $scope.$apply(function() {
                return $scope.signup_error = "There was an error sending the confirmation email : " + err;
              });
            } else {
              return CloudBrowserDb.collection("users", function(err, collection) {
                if (err) {
                  $scope.$apply(function() {
                    return $scope.signup_error = "Our system encountered an error! Please try again later.";
                  });
                  throw err;
                } else {
                  return HashPassword({
                    password: $scope.password
                  }, function(result) {
                    var user;
                    user = {
                      email: $scope.email,
                      key: result.key.toString('hex'),
                      salt: result.salt.toString('hex'),
                      status: 'unverified',
                      token: buf,
                      app: mountPoint,
                      ns: 'local'
                    };
                    collection.insert(user);
                    return $scope.$apply(function() {
                      return $scope.success_message = true;
                    });
                  });
                }
              });
            }
          });
        });
      }
    };
    return $scope.googleLogin = googleLogin;
  });

}).call(this);
