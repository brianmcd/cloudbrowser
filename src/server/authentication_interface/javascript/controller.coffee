CBAuthentication = angular.module("CBAuthentication", [])
Mongo = require("mongodb")
Express = require("express")
MongoStore = require("connect-mongo")(Express)
Https = require('https')
Xml2JS = require('xml2js')
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

authentication_string = "?openid.ns=http://specs.openid.net/auth/2.0" +
  "&openid.ns.pape=http:\/\/specs.openid.net/extensions/pape/1.0" +
  "&openid.ns.max_auth_age=300" +
  "&openid.claimed_id=http:\/\/specs.openid.net/auth/2.0/identifier_select" +
  "&openid.identity=http:\/\/specs.openid.net/auth/2.0/identifier_select" +
  "&openid.return_to=" + window.bserver.domain + "/checkauth?redirectto=" + (if window.bserver.redirectURL? then window.bserver.redirectURL else "") +
  "&openid.realm=" + window.bserver.domain +
  "&openid.mode=checkid_setup" +
  "&openid.ui.ns=http:\/\/specs.openid.net/extensions/ui/1.0" +
  "&openid.ui.mode=popup" +
  "&openid.ui.icon=true" +
  "&openid.ns.ax=http:\/\/openid.net/srv/ax/1.0" +
  "&openid.ax.mode=fetch_request" +
  "&openid.ax.type.email=http:\/\/axschema.org/contact/email" +
  "&openid.ax.type.language=http:\/\/axschema.org/pref/language" +
  "&openid.ax.required=email,language"

getJSON = (options, callback) ->
  request = Https.get options, (res) ->
    output = ''
    res.setEncoding 'utf8'
    res.on 'data', (chunk) ->
      output += chunk
    res.on 'end', ->
      callback res.statusCode, output
  request.on 'error', (err) ->
    callback -1, err
  request.end

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
      getJSON "https://www.google.com/accounts/o8/id", (statusCode, result) ->
        if statusCode == -1
          console.log "OpenID Discovery Endpoint " + result
          $scope.$apply ->
            $scope.login_error="There was a failure in contacting the google discovery service"
        Xml2JS.parseString result, (err, result) ->
          uri = result["xrds:XRDS"].XRD[0].Service[0].URI[0]
          path = uri.substring(uri.indexOf('\.com') + 4)
          window.bserver.redirect("https://www.google.com" + path + authentication_string)
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
  $scope.password_error = null
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
    $scope.password_error = ""
    $scope.isDisabled = false
    if $scope.password != $scope.vpassword
      $scope.isDisabled = true
      $scope.password_error = "Passwords don't match!"

  $scope.signup = ->
    $scope.isDisabled = true
    if !$scope.email? or !$scope.password?
      $scope.signup_error = "Must provide both Email and Password!"
    else if not /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test($scope.email.toUpperCase())
      $scope.email_error = "Not a valid Email ID!"
    else if not /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\da-zA-Z])\S{8,15}$/.test($scope.password)
      $scope.password_error = "Password must be have a length between 8 - 15 characters, must contain atleast 1 <strong>uppercase</strong>, 1 <strong>lowercase</strong>, 1 <strong>digit</strong> and 1 <strong>special character</strong>. Spaces are not allowed."
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
