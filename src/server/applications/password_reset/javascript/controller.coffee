CBPasswordReset         = angular.module("CBPasswordReset", [])
Mongo                   = require("mongodb")
Util                    = require("util")
Crypto                  = require("crypto")
CloudBrowserDb_server   = new Mongo.Server(config.domain, 27017,
    auto_reconnect: true
)
CloudBrowserDb          = new Mongo.Db("cloudbrowser", CloudBrowserDb_server)
CloudBrowserDb.open (err, Db) ->
    if err then throw err

defaults =
    iterations : 10000
    randomPasswordStartLen : 6 #final password length after base64 encoding will be 8
    saltLength : 64

HashPassword = (config={}, callback) ->
    for own k, v of defaults
        config[k] = if config.hasOwnProperty k then config[k] else v

    if not config.password?
        Crypto.randomBytes config.randomPasswordStartLen, (err, buf) ->
            if err then throw err
            else
                config.password = buf.toString 'base64'
                HashPassword config, callback

    else if not config.salt?
        Crypto.randomBytes config.saltLength, (err, buf) ->
            if err then throw err
            else
                config.salt = new Buffer buf
                HashPassword config, callback

    else Crypto.pbkdf2 config.password, config.salt, config.iterations, config.saltLength, (err, key) ->
        if err then throw err
        else
            config.key = key
            callback config

CBPasswordReset.controller "ResetCtrl", ($scope) ->

    #dictionary of all the query key value pairs
    searchStringtoJSON = (searchString) ->
        search = searchString.split("&")
        query = {}
        for s in search
            pair = s.split("=")
            query[pair[0]] = pair[1]
        return query

    search = location.search
    if search[0] == "?"
        search = search.slice(1)

    query = searchStringtoJSON(search)

    username = query['user'].split("@")[0]
    $scope.username = username.charAt(0).toUpperCase() + username.slice(1)
    $scope.password = null
    $scope.vpassword = null
    $scope.isDisabled = false
    $scope.password_error = null
    $scope.password_success = null

    $scope.$watch "password", ->
        $scope.password_error = null
        $scope.password_success = null
        $scope.isDisabled = false
    
    $scope.reset = ->
        $scope.isDisabled = true
        username = query['user']
        token    = query['token']
        password = $scope.password
        if not password? or not /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\da-zA-Z])\S{8,15}$/.test password
            $scope.password_error = "Password must be have a length between 8 - 15 characters, must contain atleast 1 uppercase, 1 lowercase, 1 digit and 1 special character. Spaces are not allowed."

        #verify validity of the request by comparing the token
        else CloudBrowserDb.collection "users", (err, collection) ->
            unless err
                collection.findOne {email: username}, (err, user) ->
                    if user and user.status is "reset_password" and user.token is token
                        collection.update {email: username}, {$unset: {token: "", status: ""}}, {w:1}, (err, result) ->
                            if err then throw err
                            else HashPassword {password:password}, (result) ->
                                collection.update {email: username}, {$set: {key: result.key.toString('hex'), salt: result.salt.toString('hex')}}, (err, result) ->
                                    if err then throw err
                                    else
                                        $scope.$apply ->
                                            $scope.password_success = "The password has been successfully reset"
                    else
                        $scope.$apply ->
                            $scope.password_error = "Invalid reset request"
            else throw err
       $scope.isDisabled = false
