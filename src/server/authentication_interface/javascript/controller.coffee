CBAuthentication = angular.module("CBAuthentication", [])
Mongo = require("mongodb")
Express = require("express")
MongoStore = require("connect-mongo")(Express)
CloubBrowserDb_server = new Mongo.Server("localhost", 27017,
  auto_reconnect: true
)
CloudBrowserDb = new Mongo.Db("cloudbrowser", CloudBrowserDb_server)
mongoStore = new MongoStore(db: "cloudbrowser_sessions")
redirectURL = window.bserver.redirectURL
CloudBrowserDb.open (err, Db) ->
  unless err
    console.log "The authentication interface is connected to the database"
  else
    console.log "The authentication interface was unable to connect to the database. Error : " + err

CBAuthentication.controller "LoginCtrl", ($scope) ->
  $scope.username = ""
  $scope.password = ""
  $scope.error = ""
  $scope.isDisabled = false
  $scope.$watch "username + password", ->
    $scope.error = ""

  $scope.login = ->
    $scope.isDisabled = true
    CloudBrowserDb.collection "users", (err, collection) ->
      unless err
        collection.findOne
          username: $scope.username
        , (err, item) ->
          if item and item.password is $scope.password
            sessionID = decodeURIComponent(window.bserver.getSessions()[0]["cb.id"])
            mongoStore.get sessionID, (err, session) ->
              unless err
                session.user = $scope.username
                mongoStore.set sessionID, session, ->

                if redirectURL
                  window.bserver.redirect "http://localhost:3000" + redirectURL
                else
                  window.bserver.redirect "http://localhost:3000"
              else
                console.log "Error in finding the session:" + sessionID + " Error:" + err

          else
            $scope.$apply $scope.error = 1

      else
        console.log "The authentication interface was unable to connect to the users collection. Error:" + err
      $scope.isDisabled = false


CBAuthentication.controller "SignupCtrl", ($scope) ->
  $scope.username = ""
  $scope.password = ""
  $scope.vpassword = ""
  $scope.uerror = ""
  $scope.isDisabled = false
  $scope.$watch "username", (nval, oval) ->
    $scope.uerror = ""
    $scope.isDisabled = false
    CloudBrowserDb.collection "users", (err, collection) ->
      unless err
        collection.findOne
          username: nval
        , (err, item) ->
          if item
            $scope.$apply ->
              $scope.uerror = 1
              $scope.isDisabled = true


      else
        console.log "The authentication interface was unable to connect to the users collection. Error:" + err


  $scope.signup = ->
    $scope.isDisabled = true
    CloudBrowserDb.collection "users", (err, collection) ->
      unless err
        user =
          username: $scope.username
          password: $scope.password

        collection.insert user
        sessionID = decodeURIComponent(window.bserver.getSessions()[0]["cb.id"])
        mongoStore.get sessionID, (err, session) ->
          session.user = $scope.username
          mongoStore.set sessionID, session, ->

          if redirectURL
            window.bserver.redirect "http://localhost:3000" + redirectURL
          else
            window.bserver.redirect "http://localhost:3000"



      else
        console.log "The authentication interface was unable to connect to the users collection. Error:" + err
