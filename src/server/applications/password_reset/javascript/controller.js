(function() {
  var CBPasswordReset, CloudBrowserDb, CloudBrowserDb_server, Crypto, HashPassword, Mongo, Util, defaults,
    __hasProp = Object.prototype.hasOwnProperty;

  CBPasswordReset = angular.module("CBPasswordReset", []);

  Mongo = require("mongodb");

  Util = require("util");

  Crypto = require("crypto");

  CloudBrowserDb_server = new Mongo.Server(config.domain, 27017, {
    auto_reconnect: true
  });

  CloudBrowserDb = new Mongo.Db("cloudbrowser", CloudBrowserDb_server);

  CloudBrowserDb.open(function(err, Db) {
    if (err) throw err;
  });

  defaults = {
    iterations: 10000,
    randomPasswordStartLen: 6,
    saltLength: 64
  };

  HashPassword = function(config, callback) {
    var k, v;
    if (config == null) config = {};
    for (k in defaults) {
      if (!__hasProp.call(defaults, k)) continue;
      v = defaults[k];
      config[k] = config.hasOwnProperty(k) ? config[k] : v;
    }
    if (!(config.password != null)) {
      return Crypto.randomBytes(config.randomPasswordStartLen, function(err, buf) {
        if (err) {
          throw err;
        } else {
          config.password = buf.toString('base64');
          return HashPassword(config, callback);
        }
      });
    } else if (!(config.salt != null)) {
      return Crypto.randomBytes(config.saltLength, function(err, buf) {
        if (err) {
          throw err;
        } else {
          config.salt = new Buffer(buf);
          return HashPassword(config, callback);
        }
      });
    } else {
      return Crypto.pbkdf2(config.password, config.salt, config.iterations, config.saltLength, function(err, key) {
        if (err) {
          throw err;
        } else {
          config.key = key;
          return callback(config);
        }
      });
    }
  };

  CBPasswordReset.controller("ResetCtrl", function($scope) {
    var query, search, searchStringtoJSON, username;
    searchStringtoJSON = function(searchString) {
      var pair, query, s, search, _i, _len;
      search = searchString.split("&");
      query = {};
      for (_i = 0, _len = search.length; _i < _len; _i++) {
        s = search[_i];
        pair = s.split("=");
        query[pair[0]] = pair[1];
      }
      return query;
    };
    search = location.search;
    if (search[0] === "?") search = search.slice(1);
    query = searchStringtoJSON(search);
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
