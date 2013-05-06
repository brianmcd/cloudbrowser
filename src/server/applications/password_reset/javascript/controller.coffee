CBPasswordReset         = angular.module("CBPasswordReset", [])
query = Utils.searchStringtoJSON(location.search)

CBPasswordReset.controller "ResetCtrl", ($scope) ->

    email                   = query['user'].split("@")[0]
    $scope.email            = email.charAt(0).toUpperCase() + email.slice(1)
    $scope.password         = null
    $scope.vpassword        = null
    $scope.isDisabled       = false
    $scope.passwordError    = null
    $scope.passwordSuccess  = null

    $scope.$watch "password", () ->
        $scope.passwordError    = null
        $scope.passwordSuccess  = null
        $scope.isDisabled       = false
    
    $scope.reset = () ->

        $scope.isDisabled   = true
        email               = query['user']
        token               = query['token']

        if not $scope.password? or
        not /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\da-zA-Z])\S{8,15}$/.test($scope.password)
            $scope.passwordError = "Password must be have a length between 8 - 15 characters," +
            " must contain atleast 1 uppercase, 1 lowercase, 1 digit and 1 special character." +
            " Spaces are not allowed."

        else
            CloudBrowser.app.resetPassword {email:query['user'], ns:'local'}, $scope.password, token, (success) ->
                $scope.$apply ->
                    if success
                            $scope.passwordSuccess = "The password has been successfully reset"
                    else
                            $scope.passwordError = "Password can not be changed as the link has expired."
                $scope.isDisabled = false
