var CBAuthentication = angular.module('CBAuthentication', [])
var Mongo = require('mongodb');
var express = require('express');
var MongoStore = require('connect-mongo')(express);
var db_server = new Mongo.Server('localhost', 27017, {auto_reconnect:true})
var DB = new Mongo.Db('cloudbrowser', db_server)
var mongoStore = new MongoStore({db:'cloudbrowser_sessions'})
var redirect = window.bserver.redirectURL;

DB.open(function(err, DB){
  if(!err)
      console.log("Connected to Database")
  else
      console.log("Database Connection Error : " + err)
});

CBAuthentication.controller('LoginCtrl', function($scope) {
	$scope.username = "";
	$scope.password = "";
	$scope.error = "";
	$scope.isDisabled = false;
	$scope.$watch('username + password', function(){$scope.error = ""});
	$scope.login = function(){
		$scope.isDisabled = true;
    DB.collection('users', function(err, collection){
      if(!err){
        collection.findOne({username:$scope.username}, function (err, item){
          if(item && item.password == $scope.password){
            var sessionID = decodeURIComponent(window.bserver.getSessions()[0].split('=')[1]);
            mongoStore.get(sessionID, function(err, session){
              session.user = $scope.username;
              mongoStore.set(sessionID, session, function(){});
              if(redirect)
                window.bserver.redirect("http://localhost:3000" + redirect);
              else
                window.bserver.redirect("http://localhost:3000");
            });
          }
          else{
            $scope.$apply($scope.error = 1)
          }
        });
      }else{
        console.log("Database error: " + err);
      }
      $scope.isDisabled = false;
    });
  }
});

CBAuthentication.controller('SignupCtrl', function ($scope) {
	$scope.username = "";
	$scope.password = "";
	$scope.vpassword = "";
	$scope.uerror = "";
	$scope.isDisabled = false;
	$scope.$watch('username', function(nval,oval){
    $scope.uerror = "";
    $scope.isDisabled = false;
    DB.collection('users', function(err, collection){
      if(!err){
        collection.findOne({username:nval}, function (err, item){
          if(item){
            $scope.$apply(function(){$scope.uerror = 1; $scope.isDisabled = true;});
          }
        });
      }else{
        console.log("Database error: " + err);
      }
    });
  });
	$scope.signup = function(){
		$scope.isDisabled = true;
    DB.collection('users', function(err, collection){
      if(!err){
        user = {username:$scope.username, password:$scope.password};
        collection.insert(user);
        var sessionID = decodeURIComponent(window.bserver.getSessions()[0].split('=')[1]);
        mongoStore.get(sessionID, function(err, session){
          session.user = $scope.username;
          mongoStore.set(sessionID, session, function(){});
          if(redirect)
            window.bserver.redirect("http://localhost:3000" + redirect);
          else
            window.bserver.redirect("http://localhost:3000");
        });
      }
    });
  };
});
