CBAuthentication = angular.module("CBAuthentication", [])

# API Objects
curVB          = cloudbrowser.currentVirtualBrowser
auth           = cloudbrowser.auth
appConfig      = curVB.getAppConfig()
googleStrategy = auth.getGoogleStrategy()
localStrategy  = auth.getLocalStrategy()
{User}         = cloudbrowser.app

# Status Strings
AUTH_FAIL            = "Invalid credentials"
EMAIL_IN_USE         = "Account with this Email ID already exists"
EMAIL_INVALID        = "Please provide a valid email ID"
RESET_SUCCESS        = "A password reset link has been sent to your email ID"
EMAIL_EMPTY          = "Please provide the Email ID"
PASSWORD_EMPTY       = "Please provide the password"

# Regular expressions
EMAIL_RE             = /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/

CBAuthentication.controller "LoginCtrl", ($scope) ->
    $scope.safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase is '$apply' or phase is '$digest'
            if fn then fn()
        else this.$apply(fn)

    # Initialization
    $scope.email            = null
    $scope.password         = null
    $scope.emailError       = null
    $scope.passwordError    = null
    $scope.loginError       = null
    $scope.resetSuccessMsg  = null
    $scope.isDisabled       = false
    $scope.showEmailButton  = false

    # Watches
    $scope.$watch "email + password", () ->
        $scope.loginError       = null
        $scope.isDisabled       = false
        $scope.resetSuccessMsg  = null
    
    $scope.$watch "email", () -> $scope.emailError = null
    $scope.$watch "password", () -> $scope.passwordError = null

    # Methods on angular scope
    $scope.googleLogin = () -> googleStrategy.login()

    $scope.login = () ->
        if not $scope.email then $scope.emailError = EMAIL_EMPTY
        else if not $scope.password then $scope.passwordError = PASSWORD_EMPTY
        else
            $scope.isDisabled = true
            localStrategy.login
                user     : new User($scope.email, 'local')
                password : $scope.password
                callback : (err, success) ->
                    $scope.safeApply ->
                        if err then $scope.loginError = err.message
                        else if not success then $scope.loginError = AUTH_FAIL
                        # We redirect on success and kill this VB
                        # so there's no need to display a success message
                        $scope.isDisabled = false

    $scope.sendResetLink = () ->
        if not ($scope.email and EMAIL_RE.test($scope.email.toUpperCase()))
            $scope.emailError = EMAIL_INVALID
        else
            user = new User($scope.email, 'local')
            $scope.resetDisabled = true
            auth.sendResetLink user, (err, success) ->
                $scope.safeApply ->
                    if err then $scope.emailError = err.message
                    else $scope.resetSuccessMsg = RESET_SUCCESS
                    $scope.resetDisabled = false

CBAuthentication.controller "SignupCtrl", ($scope) ->
    $scope.safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase is '$apply' or phase is '$digest'
            if fn then fn()
        else this.$apply(fn)

    # Initialization
    $scope.email            = null
    $scope.password         = null
    $scope.vpassword        = null
    $scope.emailError       = null
    $scope.signupError      = null
    $scope.passwordError    = null
    $scope.successMessage   = false
    $scope.isDisabled       = false

    # Watches
    $scope.$watch "email", (nval, oval) ->
        $scope.emailError     = null
        $scope.signupError    = null
        $scope.isDisabled     = false
        $scope.successMessage = false
        user = new User($scope.email, 'local')
        appConfig.isUserRegistered user, (err, exists) ->
            $scope.safeApply () ->
                if err then $scope.emailError = err.message
                else if not exists then return
                $scope.emailError = EMAIL_IN_USE
                $scope.isDisabled = true

    $scope.$watch "password+vpassword", ->
        $scope.isDisabled    = false
        $scope.signupError   = null
        $scope.passwordError = null

    # Methods on the angular scope
    $scope.googleLogin = () -> googleStrategy.signup()

    $scope.signup = () ->
        $scope.isDisabled = true
        if not ($scope.email and EMAIL_RE.test($scope.email.toUpperCase()))
            $scope.emailError = EMAIL_INVALID
        else if not $scope.password then $scope.passwordError = PASSWORD_EMPTY
        else
            localStrategy.signup
                user     : new User($scope.email, 'local')
                password : $scope.password
                callback : (err) ->
                    $scope.safeApply ->
                        if err then $scope.signupError = err.message
                        else $scope.successMessage = true
