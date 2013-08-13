CBPasswordReset         = angular.module("CBPasswordReset", [])

CBPasswordReset.controller "ResetCtrl", ($scope) ->

    currentVirtualBrowser = cloudbrowser.currentVirtualBrowser
    auth = cloudbrowser.auth
    currentVirtualBrowser.getResetEmail (userEmail) ->
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

        if not $scope.password?
            $scope.passwordError = "Please enter the password."

        else
            auth.resetPassword $scope.password, (success) ->
                $scope.$apply ->
                    if success
                            $scope.passwordSuccess = "The password has been successfully reset"
                    else
                            $scope.passwordError = "Password can not be changed as the reset link is invalid."
                    $scope.isDisabled = false
