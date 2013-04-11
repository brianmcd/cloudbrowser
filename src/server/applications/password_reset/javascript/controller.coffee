CBPasswordReset         = angular.module("CBPasswordReset", [])
CloudBrowserDb          = server.db

CBPasswordReset.controller "ResetCtrl", ($scope) ->

    query = Utils.searchStringtoJSON(location.search)

    username = query['user'].split("@")[0]
    $scope.username = username.charAt(0).toUpperCase() + username.slice(1)
    $scope.password = null
    $scope.vpassword = null
    $scope.isDisabled = false
    $scope.password_error = null
    $scope.password_success = null
    mountPoint              = Utils.getAppMountPoint bserver.mountPoint, "password_reset"
    app                     = server.applicationManager.find mountPoint

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
        else CloudBrowserDb.collection app.dbName, (err, collection) ->
            unless err
                collection.findOne {email: username, ns: 'local'}, (err, user) ->
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
