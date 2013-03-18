Mongo                   = require("mongodb")
Express                 = require("express")
MongoStore              = require("connect-mongo")(Express)
Https                   = require("https")
Xml2JS                  = require("xml2js")
Crypto                  = require("crypto")
nodemailer              = require("nodemailer")
CBAuthentication        = angular.module("CBAuthentication", [])
CloudBrowserDb_server   = new Mongo.Server(config.domain, 27017,
    auto_reconnect: true
)
CloudBrowserDb          = new Mongo.Db("cloudbrowser", CloudBrowserDb_server)
mongoStore              = new MongoStore(db: "cloudbrowser_sessions")
#redirectURL            = bserver.redirectURL
#console.log "REDIRECT" + redirectURL
mountPoint              = bserver.mountPoint.split("/")[1]
rootURL                 = "http://" + config.domain + ":" + config.port
baseURL                 = rootURL + "/" + mountPoint

defaults =
    iterations : 10000
    randomPasswordStartLen : 6 #final password length after base64 encoding will be 8
    saltLength : 64

HashPassword = (config={}, callback) ->
    for own k, v of defaults
        config[k] = if config.hasOwnProperty k then config[k] else v

    if not config.password?
        Crypto.randomBytes config.randomPasswordStartLen, (err, buf) ->
            if err
                console.log err
            else
                config.password = buf.toString 'base64'
                HashPassword config, callback

    else if not config.salt?
        Crypto.randomBytes config.saltLength, (err, buf) ->
            if err
                console.log err
            else
                config.salt = new Buffer buf
                HashPassword config, callback

    else Crypto.pbkdf2 config.password, config.salt, config.iterations, config.saltLength, (err, key) ->
        if err
            console.log err
        else
            config.key = key
            callback config

sendEmail = (toEmailID, subject, message, callback) ->
    smtpTransport = nodemailer.createTransport "SMTP",
        service: "Gmail"
        auth:
            user: "ashimaathri@gmail.com"
            pass: "Jgilson*2716"

    mailOptions =
        from: "ashimaathri@gmail.com"
        to: toEmailID
        subject: subject
        html: message

    smtpTransport.sendMail mailOptions, (error, response) ->
        if error then callback error
        else callback null
        smtpTransport.close()

CloudBrowserDb.open (err, Db) ->
    if err then console.log err

authentication_string = "?openid.ns=http://specs.openid.net/auth/2.0" +
    "&openid.ns.pape=http:\/\/specs.openid.net/extensions/pape/1.0" +
    "&openid.ns.max_auth_age=300" +
    "&openid.claimed_id=http:\/\/specs.openid.net/auth/2.0/identifier_select" +
    "&openid.identity=http:\/\/specs.openid.net/auth/2.0/identifier_select" +
    "&openid.return_to=" + baseURL + "/checkauth?redirectto=" + (if bserver.redirectURL? then bserver.redirectURL else "") +
    "&openid.realm=" + rootURL +
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
            CloudBrowserDb.collection "users", (err, collection) ->
                unless err
                    collection.findOne {email: $scope.email}, (err, user) ->
                        if user and user.status isnt 'unverified'
                            HashPassword {password : $scope.password, salt : new Buffer(user.salt, 'hex')}, (result) ->
                                if result.key.toString('hex') == user.key
                                    sessionID = decodeURIComponent(bserver.getSessions()[0])
                                    mongoStore.get sessionID, (err, session) ->
                                        unless err
                                            session.user = $scope.email
                                            ### Remember me
                                            if $scope.remember
                                                session.cookie.maxAge = 24 * 60 * 60 * 1000
                                                #notify the client
                                                bserver.updateCookie(session.cookie.maxAge)
                                            else
                                                session.cookie.expires = false
                                            ###
                                            mongoStore.set sessionID, session, ->
                                                if redirectURL? then bserver.redirect baseURL + redirectURL
                                                else bserver.redirect baseURL
                                        else
                                            console.log "Error in finding the session:" + sessionID + " Error:" + err
                                else $scope.$apply ->
                                    $scope.login_error = "Invalid Credentials"
                        else $scope.$apply ->
                            $scope.login_error = "Invalid Credentials"
                else
                    console.log err
            $scope.isDisabled = false

    $scope.googleLogin = ->
        getJSON "https://www.google.com/accounts/o8/id", (statusCode, result) ->
            if statusCode == -1 then $scope.$apply ->
                $scope.login_error="There was a failure in contacting the google discovery service"
            else Xml2JS.parseString result, (err, result) ->
                uri = result["xrds:XRDS"].XRD[0].Service[0].URI[0]
                path = uri.substring(uri.indexOf('\.com') + 4)
                bserver.redirect("https://www.google.com" + path + authentication_string)

    $scope.$watch "email + password", ->
        $scope.login_error = null
        $scope.isDisabled = false
        $scope.reset_success_msg = null
    
    $scope.$watch "email", ->
        $scope.email_error = null

    $scope.sendResetLink = ->
        if !$scope.email? or not /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test $scope.email.toUpperCase()
            $scope.email_error = "Please provide a valid email ID"
        else CloudBrowserDb.collection "users", (err, collection) ->
            if err then console.log err
            else collection.findOne {email: $scope.email}, (err, user) ->
                if err then console.log err
                else if not user then $scope.$apply ->
                    $scope.email_error = "This email ID is not registered with us."
                else
                    $scope.$apply ->
                        $scope.resetDisabled = true
                    Crypto.randomBytes 32, (err, buf) ->
                        if err then callback err, null
                        else
                            buf = buf.toString 'hex'
                            esc_email = encodeURIComponent($scope.email)
                            subject = "Link to reset your CloudBrowser password"
                            message = "You have requested to change your password. If you want to continue click <a href='#{baseURL}/password_reset?token=#{buf}&user=#{esc_email}'>reset</a>. If you have not requested a change in password then take no action."
                            sendEmail $scope.email, subject, message, (err) ->
                                $scope.$apply ->
                                    $scope.resetDisabled = false
                                    $scope.reset_success_msg = "A password reset link has been sent to your email ID."
                                collection.update {email:user.email}, {$set:{status:"reset_password",token:buf}}, {w:1}, (err, result) ->
                                    console.log err if err

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
        CloudBrowserDb.collection "users", (err, collection) ->
            unless err
                collection.findOne {email: nval}, (err, item) ->
                    if item then $scope.$apply ->
                        $scope.email_error = "Account with this Email ID already exists!"
                        $scope.isDisabled = true
            else
                console.log err

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
                else
                    buf = buf.toString 'hex'
                    subject="Activate your cloudbrowser account"
                    confirmationMsg = "Please click on the link below to verify your email address.<br>" +
                    "<p><a href='#{baseURL}/activate/#{buf}'>Activate your account</a></p>" +
                    "<p>If you have received this message in error and did not sign up for a cloudbrowser account," +
                    " click <a href='#{baseURL}/deactivate/#{buf}'>not my account</a></p>"
                    sendEmail $scope.email, subject, confirmationMsg, (err) ->
                        unless err
                            CloudBrowserDb.collection "users", (err, collection) ->
                                unless err
                                    HashPassword {password:$scope.password}, (result) ->
                                        user =
                                            email: $scope.email
                                            key: result.key.toString('hex')
                                            salt: result.salt.toString('hex')
                                            status: 'unverified'
                                            token: buf
                                        collection.insert user
                                        $scope.$apply ->
                                            $scope.success_message = true
                                else
                                    $scope.$apply ->
                                        $scope.signup_error = "Our system encountered an error! Please try again later."
                                    console.log err
                        else
                            $scope.$apply ->
                                $scope.signup_error = "There was an error sending the confirmation email : " + err

    $scope.googleLogin = ->
        getJSON "https://www.google.com/accounts/o8/id", (statusCode, result) ->
            if statusCode == -1 then $scope.$apply ->
                $scope.login_error="There was a failure in contacting the google discovery service"
            else Xml2JS.parseString result, (err, result) ->
                uri = result["xrds:XRDS"].XRD[0].Service[0].URI[0]
                path = uri.substring(uri.indexOf('\.com') + 4)
                bserver.redirect("https://www.google.com" + path + authentication_string)

