(function() {
  var CBAuthentication, CloudBrowserDb, CloudBrowserDb_server, Express, Http, Https, Mongo, MongoStore, mongoStore, redirectURL;

  CBAuthentication = angular.module("CBAuthentication", []);

  Mongo = require("mongodb");

  Express = require("express");

  MongoStore = require("connect-mongo")(Express);

  Http = require('http');

  Https = require('https');

  CloudBrowserDb_server = new Mongo.Server("localhost", 27017, {
    auto_reconnect: true
  });

  CloudBrowserDb = new Mongo.Db("cloudbrowser", CloudBrowserDb_server);

  mongoStore = new MongoStore({
    db: "cloudbrowser_sessions"
  });

  redirectURL = window.bserver.redirectURL;

  CloudBrowserDb.open(function(err, Db) {
    if (!err) {
      return console.log("The authentication interface is connected to the database");
    } else {
      return console.log("The authentication interface was unable to connect to the database. Error : " + err);
    }
  });

  /*
  OpenIDEndpoint
    host: 'www.google.com'
    port: 443
    path: '/accounts/o8/id'
    method: 'GET'
    headers:
      'Content-Type': 'application/xrds+xml'
  
  GoogleAuthenticationEndpoint
    host: 'www.google.com'
    port: 443
    path: ''
    method: 'GET'
  */

  CBAuthentication.controller("LoginCtrl", function($scope) {
    $scope.email = null;
    $scope.password = null;
    $scope.login_error = null;
    $scope.loginText = "Continue";
    $scope.isDisabled = false;
    $scope.showPassword = false;
    $scope.buttonState = 0;
    $scope["continue"] = function() {
      if (!($scope.email != null)) {
        return $scope.login_error = "Please provide the Email ID";
      } else if (/@gmail\.com$/.test($scope.email)) {
        return console.log("Login through gmail");
      } else if ($scope.buttonState === 0) {
        $scope.loginText = "Log In";
        $scope.buttonState = 1;
        return $scope.showPassword = true;
      } else {
        $scope.isDisabled = true;
        if (!($scope.email != null) || !($scope.password != null)) {
          return $scope.login_error = "Please provide both the Email ID and the Password";
        } else {
          return CloudBrowserDb.collection("users", function(err, collection) {
            if (!err) {
              collection.findOne({
                email: $scope.email
              }, function(err, item) {
                var sessionID;
                if (item && item.password === $scope.password) {
                  sessionID = decodeURIComponent(window.bserver.getSessions()[0]);
                  return mongoStore.get(sessionID, function(err, session) {
                    if (!err) {
                      session.user = $scope.email;
                      mongoStore.set(sessionID, session, function() {});
                      if (redirectURL) {
                        return window.bserver.redirect("http://localhost:3000" + redirectURL);
                      } else {
                        return window.bserver.redirect("http://localhost:3000");
                      }
                    } else {
                      return console.log("Error in finding the session:" + sessionID + " Error:" + err);
                    }
                  });
                } else {
                  return $scope.$apply(function() {
                    return $scope.login_error = "Username and Password do not match!";
                  });
                }
              });
            } else {
              console.log("The authentication interface was unable to connect to the users collection. Error:" + err);
            }
            return $scope.isDisabled = false;
          });
        }
      }
    };
    return $scope.$watch("email + password", function() {
      $scope.login_error = null;
      return $scope.isDisabled = false;
    });
  });

  CBAuthentication.controller("SignupCtrl", function($scope) {
    $scope.email = null;
    $scope.password = null;
    $scope.vpassword = null;
    $scope.email_error = null;
    $scope.signup_error = null;
    $scope.isDisabled = false;
    $scope.$watch("email", function(nval, oval) {
      $scope.email_error = null;
      $scope.signup_error = null;
      $scope.isDisabled = false;
      if (/@gmail\.com$/.test(nval)) {
        $scope.isDisabled = true;
        return $scope.email_error = "Please Log In Directly with your Gmail ID";
      } else {
        return CloudBrowserDb.collection("users", function(err, collection) {
          if (!err) {
            return collection.findOne({
              email: nval
            }, function(err, item) {
              if (item) {
                return $scope.$apply(function() {
                  $scope.email_error = "Account with this Email ID already exists";
                  return $scope.isDisabled = true;
                });
              }
            });
          } else {
            return console.log("The authentication interface was unable to connect to the users collection. Error:" + err);
          }
        });
      }
    });
    $scope.$watch("password+vpassword", function() {
      $scope.signup_error = "";
      $scope.isDisabled = false;
      if ($scope.password !== $scope.vpassword) return $scope.isDisabled = true;
    });
    return $scope.signup = function() {
      $scope.isDisabled = true;
      if (!($scope.email != null) || !($scope.password != null)) {
        $scope.signup_error = "Must provide both Email and Password!";
      }
      console.log($scope.email.toUpperCase());
      console.log(/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test($scope.email.toUpperCase()));
      if (!/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test($scope.email.toUpperCase())) {
        return $scope.email_error = "Not a valid Email ID!";
      } else {
        return CloudBrowserDb.collection("users", function(err, collection) {
          var sessionID, user;
          if (!err) {
            user = {
              email: $scope.email,
              password: $scope.password
            };
            collection.insert(user);
            sessionID = decodeURIComponent(window.bserver.getSessions()[0]);
            return mongoStore.get(sessionID, function(err, session) {
              session.user = $scope.email;
              mongoStore.set(sessionID, session, function() {});
              if (redirectURL) {
                return window.bserver.redirect("http://localhost:3000" + redirectURL);
              } else {
                return window.bserver.redirect("http://localhost:3000");
              }
            });
          } else {
            return console.log("The authentication interface was unable to connect to the users collection. Error:" + err);
          }
        });
      }
    };
  });

}).call(this);
