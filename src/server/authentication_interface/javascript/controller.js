(function() {
  var CBAuthentication, CloudBrowserDb, CloudBrowserDb_server, Express, Mongo, MongoStore, mongoStore, redirectURL;

  CBAuthentication = angular.module("CBAuthentication", []);

  Mongo = require("mongodb");

  Express = require("express");

  MongoStore = require("connect-mongo")(Express);

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

  CBAuthentication.controller("LoginCtrl", function($scope) {
    $scope.username = "";
    $scope.password = "";
    $scope.error = "";
    $scope.isDisabled = false;
    $scope.$watch("username + password", function() {
      return $scope.error = "";
    });
    return $scope.login = function() {
      $scope.isDisabled = true;
      return CloudBrowserDb.collection("users", function(err, collection) {
        if (!err) {
          collection.findOne({
            username: $scope.username
          }, function(err, item) {
            var sessionID;
            if (item && item.password === $scope.password) {
              sessionID = decodeURIComponent(window.bserver.getSessions()[0]);
              return mongoStore.get(sessionID, function(err, session) {
                if (!err) {
                  session.user = $scope.username;
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
              return $scope.$apply($scope.error = 1);
            }
          });
        } else {
          console.log("The authentication interface was unable to connect to the users collection. Error:" + err);
        }
        return $scope.isDisabled = false;
      });
    };
  });

  CBAuthentication.controller("SignupCtrl", function($scope) {
    $scope.username = "";
    $scope.password = "";
    $scope.vpassword = "";
    $scope.uerror = "";
    $scope.isDisabled = false;
    $scope.$watch("username", function(nval, oval) {
      $scope.uerror = "";
      $scope.isDisabled = false;
      return CloudBrowserDb.collection("users", function(err, collection) {
        if (!err) {
          return collection.findOne({
            username: nval
          }, function(err, item) {
            if (item) {
              return $scope.$apply(function() {
                $scope.uerror = 1;
                return $scope.isDisabled = true;
              });
            }
          });
        } else {
          return console.log("The authentication interface was unable to connect to the users collection. Error:" + err);
        }
      });
    });
    return $scope.signup = function() {
      $scope.isDisabled = true;
      return CloudBrowserDb.collection("users", function(err, collection) {
        var sessionID, user;
        if (!err) {
          user = {
            username: $scope.username,
            password: $scope.password
          };
          collection.insert(user);
          sessionID = decodeURIComponent(window.bserver.getSessions()[0]);
          return mongoStore.get(sessionID, function(err, session) {
            session.user = $scope.username;
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
    };
  });

}).call(this);
