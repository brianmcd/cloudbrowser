(function() {
  var CBAuthentication, CloudBrowserDb, CloudBrowserDb_server, Express, Https, Mongo, MongoStore, Xml2JS, authentication_string, baseURL, getJSON, mongoStore, mountPoint, redirectURL;

  CBAuthentication = angular.module("CBAuthentication", []);

  Mongo = require("mongodb");

  Express = require("express");

  MongoStore = require("connect-mongo")(Express);

  Https = require('https');

  Xml2JS = require('xml2js');

  CloudBrowserDb_server = new Mongo.Server("localhost", 27017, {
    auto_reconnect: true
  });

  CloudBrowserDb = new Mongo.Db("cloudbrowser", CloudBrowserDb_server);

  mongoStore = new MongoStore({
    db: "cloudbrowser_sessions"
  });

  redirectURL = bserver.redirectURL;

  console.log("REDIRECT" + redirectURL);

  mountPoint = bserver.mountPoint.split("/")[1];

  baseURL = "http://" + config.domain + ":" + config.port + "/" + mountPoint;

  console.log(baseURL);

  CloudBrowserDb.open(function(err, Db) {
    if (!err) {
      return console.log("The authentication interface is connected to the database");
    } else {
      return console.log("The authentication interface was unable to connect to the database. Error : " + err);
    }
  });

  authentication_string = "?openid.ns=http://specs.openid.net/auth/2.0" + "&openid.ns.pape=http:\/\/specs.openid.net/extensions/pape/1.0" + "&openid.ns.max_auth_age=300" + "&openid.claimed_id=http:\/\/specs.openid.net/auth/2.0/identifier_select" + "&openid.identity=http:\/\/specs.openid.net/auth/2.0/identifier_select" + "&openid.return_to=" + bserver.domain + "/checkauth?redirectto=" + (bserver.redirectURL != null ? bserver.redirectURL : "") + "&openid.realm=" + bserver.domain + "&openid.mode=checkid_setup" + "&openid.ui.ns=http:\/\/specs.openid.net/extensions/ui/1.0" + "&openid.ui.mode=popup" + "&openid.ui.icon=true" + "&openid.ns.ax=http:\/\/openid.net/srv/ax/1.0" + "&openid.ax.mode=fetch_request" + "&openid.ax.type.email=http:\/\/axschema.org/contact/email" + "&openid.ax.type.language=http:\/\/axschema.org/pref/language" + "&openid.ax.required=email,language";

  getJSON = function(options, callback) {
    var request;
    request = Https.get(options, function(res) {
      var output;
      output = '';
      res.setEncoding('utf8');
      res.on('data', function(chunk) {
        return output += chunk;
      });
      return res.on('end', function() {
        return callback(res.statusCode, output);
      });
    });
    request.on('error', function(err) {
      return callback(-1, err);
    });
    return request.end;
  };

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
        return getJSON("https://www.google.com/accounts/o8/id", function(statusCode, result) {
          if (statusCode === -1) {
            console.log("OpenID Discovery Endpoint " + result);
            $scope.$apply(function() {
              return $scope.login_error = "There was a failure in contacting the google discovery service";
            });
          }
          return Xml2JS.parseString(result, function(err, result) {
            var path, uri;
            uri = result["xrds:XRDS"].XRD[0].Service[0].URI[0];
            path = uri.substring(uri.indexOf('\.com') + 4);
            return bserver.redirect("https://www.google.com" + path + authentication_string);
          });
        });
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
                  sessionID = decodeURIComponent(bserver.getSessions()[0]);
                  return mongoStore.get(sessionID, function(err, session) {
                    if (!err) {
                      session.user = $scope.email;
                      mongoStore.set(sessionID, session, function() {});
                      if (redirectURL) {
                        return bserver.redirect(baseURL + redirectURL);
                      } else {
                        return bserver.redirect(baseURL);
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
    $scope.password_error = null;
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
      $scope.password_error = "";
      $scope.isDisabled = false;
      if ($scope.password !== $scope.vpassword) {
        $scope.isDisabled = true;
        return $scope.password_error = "Passwords don't match!";
      }
    });
    return $scope.signup = function() {
      $scope.isDisabled = true;
      if (!($scope.email != null) || !($scope.password != null)) {
        return $scope.signup_error = "Must provide both Email and Password!";
      } else if (!/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test($scope.email.toUpperCase())) {
        return $scope.email_error = "Not a valid Email ID!";
      } else if (!/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\da-zA-Z])\S{8,15}$/.test($scope.password)) {
        return $scope.password_error = "Password must be have a length between 8 - 15 characters, must contain atleast 1 <strong>uppercase</strong>, 1 <strong>lowercase</strong>, 1 <strong>digit</strong> and 1 <strong>special character</strong>. Spaces are not allowed.";
      } else {
        return CloudBrowserDb.collection("users", function(err, collection) {
          var sessionID, user;
          if (!err) {
            user = {
              email: $scope.email,
              password: $scope.password
            };
            collection.insert(user);
            sessionID = decodeURIComponent(bserver.getSessions()[0]);
            return mongoStore.get(sessionID, function(err, session) {
              session.user = $scope.email;
              mongoStore.set(sessionID, session, function() {});
              if (redirectURL) {
                return bserver.redirect(baseURL + redirectURL);
              } else {
                return bserver.redirect(baseURL);
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
