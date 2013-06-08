CBPasswordReset         = angular.module("CBPasswordReset", [])

CBPasswordReset.controller "ResetCtrl", ($scope) ->

    CloudBrowser.auth.getResetEmail (userEmail) ->
        $scope.$apply ->
            $scope.email = userEmail.split("@")[0]
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

        if not $scope.password? or
        not /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\da-zA-Z])\S{8,15}$/.test($scope.password)
            $scope.passwordError = "Password must be have a length between 8 - 15 characters," +
            " must contain atleast 1 uppercase, 1 lowercase, 1 digit and 1 special character." +
            " Spaces are not allowed."

        else
            CloudBrowser.auth.resetPassword $scope.password, (success) ->
                $scope.$apply ->
                    if success
                            $scope.passwordSuccess = "The password has been successfully reset"
                    else
                            $scope.passwordError = "Password can not be changed as the reset link is invalid."
                    $scope.isDisabled = false
