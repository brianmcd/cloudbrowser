CBAuthentication = angular.module("CBAuthentication", [])
Mongo = require("mongodb")
Express = require("express")
MongoStore = require("connect-mongo")(Express)
Http = require('http')
Https = require('https')
CloudBrowserDb_server = new Mongo.Server("localhost", 27017,
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
###
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
###

CBAuthentication.controller "LoginCtrl", ($scope) ->
  $scope.email = null
  $scope.password = null
  $scope.login_error = null
  $scope.loginText = "Continue"
  $scope.isDisabled = false
  $scope.showPassword = false
  $scope.buttonState = 0
  $scope.continue = ->
    if !$scope.email?
      $scope.login_error = "Please provide the Email ID"
    else if /@gmail\.com$/.test($scope.email)
      console.log "Login through gmail"
      #Login through gmail
    else if $scope.buttonState == 0
      $scope.loginText = "Log In"
      $scope.buttonState = 1
      $scope.showPassword = true
    else
      $scope.isDisabled = true
      if !$scope.email? or !$scope.password?
        $scope.login_error = "Please provide both the Email ID and the Password"
      else
        CloudBrowserDb.collection "users", (err, collection) ->
          unless err
            collection.findOne
              email: $scope.email
            , (err, item) ->
              if item and item.password is $scope.password
                sessionID = decodeURIComponent(window.bserver.getSessions()[0])
                mongoStore.get sessionID, (err, session) ->
                  unless err
                    session.user = $scope.email
                    mongoStore.set sessionID, session, ->
                    if redirectURL
                      window.bserver.redirect "http://localhost:3000" + redirectURL
                    else
                      window.bserver.redirect "http://localhost:3000"
                  else
                    console.log "Error in finding the session:" + sessionID + " Error:" + err
              else
                $scope.$apply ->
                  $scope.login_error = "Username and Password do not match!"
          else
            console.log "The authentication interface was unable to connect to the users collection. Error:" + err
          $scope.isDisabled = false

  $scope.$watch "email + password", ->
    $scope.login_error = null
    $scope.isDisabled = false

CBAuthentication.controller "SignupCtrl", ($scope) ->
  $scope.email = null
  $scope.password = null
  $scope.vpassword = null
  $scope.email_error = null
  $scope.signup_error = null
  $scope.isDisabled = false
  $scope.$watch "email", (nval, oval) ->
    $scope.email_error = null
    $scope.signup_error = null
    $scope.isDisabled = false
    if /@gmail\.com$/.test(nval)
      $scope.isDisabled = true
      $scope.email_error = "Please Log In Directly with your Gmail ID"
    else
      CloudBrowserDb.collection "users", (err, collection) ->
        unless err
          collection.findOne
            email: nval
          , (err, item) ->
            if item
              $scope.$apply ->
                $scope.email_error = "Account with this Email ID already exists"
                $scope.isDisabled = true
        else
          console.log "The authentication interface was unable to connect to the users collection. Error:" + err

  $scope.$watch "password+vpassword", ->
    $scope.signup_error = ""
    $scope.isDisabled = false
    if $scope.password != $scope.vpassword
      $scope.isDisabled = true

  $scope.signup = ->
    $scope.isDisabled = true
    if !$scope.email? or !$scope.password?
      $scope.signup_error = "Must provide both Email and Password!"
    if not /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test($scope.email.toUpperCase())
      $scope.email_error = "Not a valid Email ID!"
    else
      CloudBrowserDb.collection "users", (err, collection) ->
        unless err
          user =
            email: $scope.email
            password: $scope.password
          collection.insert user
          sessionID = decodeURIComponent(window.bserver.getSessions()[0])
          mongoStore.get sessionID, (err, session) ->
            session.user = $scope.email
            mongoStore.set sessionID, session, ->
            if redirectURL
              window.bserver.redirect "http://localhost:3000" + redirectURL
            else
              window.bserver.redirect "http://localhost:3000"
        else
          console.log "The authentication interface was unable to connect to the users collection. Error:" + err
