CBAuthentication        = angular.module("CBAuthentication", [])
Crypto                  = require('crypto')

CloudBrowserDb          = server.db
mongoStore              = server.mongoStore
mountPoint              = Utils.getAppMountPoint bserver.mountPoint, "authenticate"
app                     = server.applicationManager.find(mountPoint)
rootURL                 = "http://" + server.config.domain + ":" + server.config.port
baseURL                 = rootURL + mountPoint

googleLogin = () ->
    search = location.search
    query = Utils.searchStringtoJSON(search)
    if search[0] is "?"
        search += "&mountPoint=" + mountPoint
    else
        search = "?mountPoint=" + mountPoint
    if not query.redirectto?
        search += "&redirectto=" + mountPoint
    bserver.redirect(rootURL + '/googleAuth' + search)

CBAuthentication.controller "LoginCtrl", ($scope) ->
    $scope.email = null
    $scope.password = null
    $scope.email_error = null
    $scope.login_error = null
    $scope.reset_success_msg = null
    $scope.isDisabled = false
    #$scope.remember = true
    $scope.show_email_button = false
    $scope.login = ->
        if not $scope.email? or not $scope.password?
            $scope.login_error = "Please provide both the Email ID and the password to login"
        else
            $scope.isDisabled = true
            CloudBrowserDb.collection app.dbName, (err, collection) ->
                if err then throw err
                collection.findOne {email: $scope.email, ns: 'local'}, (err, user) ->
                    if user and user.status isnt 'unverified'
                        HashPassword {password : $scope.password, salt : new Buffer(user.salt, 'hex')}, (result) ->
                            if result.key.toString('hex') == user.key
                                sessionID = decodeURIComponent(bserver.getSessions()[0])
                                mongoStore.get sessionID, (err, session) ->
                                    if err then throw new Error "Error in finding the session:" + sessionID + " Error:" + err
                                    else
                                        if not session.user?
                                            session.user = [{app:mountPoint, email:$scope.email, ns:'local'}]
                                        else
                                            session.user.push({app:mountPoint, email:$scope.email, ns:'local'})
                                        ### Remember me
                                        if $scope.remember
                                            session.cookie.maxAge = 24 * 60 * 60 * 1000
                                            #notify the client
                                            bserver.updateCookie(session.cookie.maxAge)
                                        else
                                            session.cookie.expires = false
                                        ###
                                        mongoStore.set sessionID, session, ->
                                            query = Utils.searchStringtoJSON(location.search)
                                            if query.redirectto? then bserver.redirect rootURL + query.redirectto
                                            else bserver.redirect baseURL
                            else $scope.$apply ->
                                $scope.login_error = "Invalid Credentials"
                    else $scope.$apply ->
                        $scope.login_error = "Invalid Credentials"
            $scope.isDisabled = false

    $scope.googleLogin = googleLogin

    $scope.$watch "email + password", ->
        $scope.login_error = null
        $scope.isDisabled = false
        $scope.reset_success_msg = null
    
    $scope.$watch "email", ->
        $scope.email_error = null

    $scope.sendResetLink = ->
        if !$scope.email? or not /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test $scope.email.toUpperCase()
            $scope.email_error = "Please provide a valid email ID"
        else CloudBrowserDb.collection app.dbName, (err, collection) ->
            if err then throw err
            collection.findOne {email: $scope.email, ns: 'local'}, (err, user) ->
                if err then throw err
                if not user then $scope.$apply ->
                    $scope.email_error = "This email ID is not registered with us."
                else
                    $scope.$apply ->
                        $scope.resetDisabled = true
                    Crypto.randomBytes 32, (err, buf) ->
                        if err then callback err, null
                        buf = buf.toString 'hex'
                        esc_email = encodeURIComponent($scope.email)
                        subject = "Link to reset your CloudBrowser password"
                        message = "You have requested to change your password. If you want to continue click <a href='#{baseURL}/password_reset?token=#{buf}&user=#{esc_email}'>reset</a>. If you have not requested a change in password then take no action."
                        sendEmail $scope.email, subject, message, server.config.nodeMailerEmailID, server.config.nodeMailerPassword, (err) ->
                            $scope.$apply ->
                                $scope.resetDisabled = false
                                $scope.reset_success_msg = "A password reset link has been sent to your email ID."
                            collection.update {email:user.email}, {$set:{status:"reset_password",token:buf}}, {w:1}, (err, result) ->
                                if err then throw err

CBAuthentication.controller "SignupCtrl", ($scope) ->
    $scope.email = null
    $scope.password = null
    $scope.vpassword = null
    $scope.email_error = null
    $scope.signup_error = null
    $scope.password_error = null
    $scope.success_message = false
    $scope.isDisabled = false
    $scope.$watch "email", (nval, oval) ->
        $scope.email_error = null
        $scope.signup_error = null
        $scope.isDisabled = false
        $scope.success_message = false
        CloudBrowserDb.collection app.dbName, (err, collection) ->
            if err then throw err
            collection.findOne {email: nval, ns: 'local'}, (err, item) ->
                if item then $scope.$apply ->
                    $scope.email_error = "Account with this Email ID already exists!"
                    $scope.isDisabled = true

    $scope.$watch "password+vpassword", ->
        $scope.signup_error = null
        $scope.password_error = null
        $scope.isDisabled = false

    $scope.signup = ->
        $scope.isDisabled = true
        if !$scope.email? or !$scope.password?
            $scope.signup_error = "Must provide both Email and Password!"
        else if not /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test $scope.email.toUpperCase()
            $scope.email_error = "Not a valid Email ID!"
        else if not /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\da-zA-Z])\S{8,15}$/.test $scope.password
            $scope.password_error = "Password must be have a length between 8 - 15 characters, must contain atleast 1 uppercase, 1 lowercase, 1 digit and 1 special character. Spaces are not allowed."
        else
            Crypto.randomBytes 32, (err, buf) ->
                if err then callback err, null
                buf = buf.toString 'hex'
                subject="Activate your cloudbrowser account"
                confirmationMsg = "Please click on the link below to verify your email address.<br>" +
                "<p><a href='#{baseURL}/activate/#{buf}'>Activate your account</a></p>" +
                "<p>If you have received this message in error and did not sign up for a cloudbrowser account," +
                " click <a href='#{baseURL}/deactivate/#{buf}'>not my account</a></p>"
                sendEmail $scope.email, subject, confirmationMsg, server.config.nodeMailerEmailID, server.config.nodeMailerPassword, (err) ->
                    if err
                        throw err
                        $scope.$apply ->
                            $scope.signup_error = "There was an error sending the confirmation email : " + err
                    else
                        CloudBrowserDb.collection app.dbName, (err, collection) ->
                            if err
                                $scope.$apply ->
                                    $scope.signup_error = "Our system encountered an error! Please try again later."
                                throw err
                            else
                                HashPassword {password:$scope.password}, (result) ->
                                    user =
                                        email: $scope.email
                                        key: result.key.toString('hex')
                                        salt: result.salt.toString('hex')
                                        status: 'unverified'
                                        token: buf
                                        app: mountPoint
                                        ns: 'local'
                                    collection.insert user

                                    $scope.$apply ->
                                        $scope.success_message = true

    $scope.googleLogin = googleLogin
