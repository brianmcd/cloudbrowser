CBPasswordReset         = angular.module("CBPasswordReset", [])

CBPasswordReset.controller "ResetCtrl", ($scope) ->
    # Status strings
    PASSWORD_EMPTY = "Please enter the password"
    RESET_SUCCESS  = "The password has been successfully reset"

    $scope.safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase is '$apply' or phase is '$digest'
            if fn then fn()
        else this.$apply(fn)
    
    # API Objects
    currentVirtualBrowser = cloudbrowser.currentVirtualBrowser
    auth                  = cloudbrowser.auth

    # Initialization
    $scope.password      = null
    $scope.vpassword     = null
    $scope.isDisabled    = false
    $scope.passwordError = null
    $scope.resetSuccess  = null
    $scope.resetError    = null

    currentVirtualBrowser.getResetEmail (err, userEmail) ->
        if err then console.log err
        else $scope.safeApply -> $scope.email = userEmail.split("@")[0]

    # Watches
    $scope.$watch "password", () ->
        $scope.passwordError    = null
        $scope.resetSuccess  = null
        $scope.isDisabled       = false
    
    $scope.reset = () ->
        $scope.isDisabled = true
        if not $scope.password then $scope.passwordError = PASSWORD_EMPTY
        else auth.resetPassword $scope.password, (err) ->
            $scope.safeApply ->
                if err then $scope.resetError = err.message
                else $scope.resetSuccess = RESET_SUCCESS
                $scope.isDisabled = false
