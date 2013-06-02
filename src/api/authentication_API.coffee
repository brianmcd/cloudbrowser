User            = require("./user")
Crypto          = require("crypto")
Nodemailer      = require("nodemailer")
{getMountPoint} = require("../shared/utils")
QueryString     = require("querystring")

# Usage : CloudBrowser.auth.APIMethod
#
# @method #logout()
#   Logs out all users connected to this application instance.    
#
# @method #login(user, password, callback)
#   Logs a user into this CloudBrowser application.
#   The password is hashed using pbkdf2.    
#   @param [User] user           The user that is trying to log in.
#   @param [String] password     The user supplied plaintext password.
#   @param [Function] callback   A boolean indicating the success/failure of the process is passed as an argument.
#
# @method #googleLogin()
#   Logs a user into the application through their gmail ID.    
#
# @method #sendEmail(toEmailID, subject, message, callback)
#   Sends an email to the specified user.
#   @param [String] toEmailID  The email ID of the user to whom the message must be sent.
#   @param [String] subject    The subject of the email.
#   @param [String] message    The content of the email.
#   @param [Function] callback No arguments are passed to the callback.
#
# @method #signup(user, password, callback)
#   Registers a user with the application and 
#   sends a confirmation email to the user's registered email ID.
#   The email ID is not activated until
#   it has been confirmed by the user.    
#   @param [User] user           The user that is trying to log in.
#   @param [String] password     The user supplied plaintext password.
#   @param [Function] callback   No arguments are supplied.
#
# @method #sendResetLink(user, callback)
#   Sends a password reset link to the user at their registered email ID.    
#   @param [Function] callback false is passed as an argument if the user is not registered with the application else, true is passed. 
#
# @method #getResetEmail(queryString)
#   Gets the user's email ID from the url
#   @param [String] queryString Must be the location.search of the instance.
# 
# @method #resetPassword(queryString, password, callback)
#   Resets the password for a valid user request.     
#   @param [String]   queryString Must be the location.search string of the instance.
#   @param [String]   password     The new plaintext password provided by the user.
#   @param [Function] callback     A boolean is passed as an argument to indicate success/failure.
class AuthenticationAPI

    hashPassword = (config={}, callback) ->
        defaults =
            iterations : 10000
            randomPasswordStartLen : 6 #final password length after base64 encoding will be 8
            saltLength : 64

        for own k, v of defaults
            config[k] = if config.hasOwnProperty(k) then config[k] else v

        if not config.password
            Crypto.randomBytes config.randomPasswordStartLen, (err, buf) =>
                throw err if err
                config.password = buf.toString('base64')
                hashPassword(config, callback)

        else if not config.salt
            Crypto.randomBytes config.saltLength, (err, buf) =>
                throw err if err
                config.salt = new Buffer(buf)
                hashPassword(config, callback)

        else
            Crypto.pbkdf2 config.password, config.salt,
            config.iterations, config.saltLength, (err, key) ->
                throw err if err
                config.key = key
                callback(config)

    # Constructs an instance of the Authentication API
    # @param [BrowserServer] bserver The object corresponding to the current browser
    # @private
    constructor : (bserver) ->

        mountPoint  = getMountPoint(bserver.mountPoint)
        application = bserver.server.applicationManager.find(mountPoint)
        db          = bserver.server.db
        mongoStore  = bserver.server.mongoStore
        config      = bserver.server.config
        appUrl      = "http://" + config.domain + ":" + config.port + mountPoint

        @auth =

            logout : () ->
                bserver.redirect(appUrl + "/logout")

            login : (user, password, callback) ->
                db.collection application.dbName, (err, collection) =>
                    if err then throw err
                    collection.findOne user.toJson(), (err, userRec) =>
                        if userRec and userRec.status isnt 'unverified'
                            hashPassword {password : password, salt : new Buffer(userRec.salt, 'hex')}, (result) =>
                                if result.key.toString('hex') is userRec.key
                                    # TODO - Allow only one user to connect to this bserver
                                    sessionID = decodeURIComponent(bserver.getSessions()[0])
                                    mongoStore.get sessionID, (err, session) ->
                                        throw err if err
                                        if not session.user
                                            session.user = [{app:mountPoint, email:user.getEmail(), ns:user.getNameSpace()}]
                                        else
                                            session.user.push({app:mountPoint, email:user.getEmail(), ns:user.getNameSpace()})
                                        redirectto = session.redirectto; session.redirectto = null

                                        mongoStore.set sessionID, session, ->
                                            if redirectto?
                                                bserver.redirect(redirectto)
                                            else
                                                bserver.redirect(appUrl)
                                            setTimeout () ->
                                                bserver.server.applicationManager.find(bserver.mountPoint).browsers.close(bserver)
                                            , 500
                                else callback(false)
                        else callback(false)

            googleLogin : () ->
                sessionID = decodeURIComponent(bserver.getSessions()[0])
                queryString = "?"
                mongoStore.get sessionID, (err, session) ->
                    throw err if err
                    session.mountPoint = mountPoint
                    mongoStore.set sessionID, session, () ->
                        bserver.redirect( "http://" + config.domain + ":" + config.port + '/googleAuth')
                        setTimeout () ->
                            bserver.server.applicationManager.find(bserver.mountPoint).browsers.close(bserver)
                        , 500

            sendEmail : (toEmailID, subject, message, callback) ->
                smtpTransport = Nodemailer.createTransport "SMTP",
                    service: "Gmail"
                    auth:
                        user: config.nodeMailerEmailID
                        pass: config.nodeMailerPassword

                mailOptions =
                    from    : config.nodeMailerEmailID
                    to      : toEmailID
                    subject : subject
                    html    : message

                smtpTransport.sendMail mailOptions, (err, response) ->
                    throw err if err
                    smtpTransport.close()
                    callback()

            signup : (user, password, callback) ->
                Crypto.randomBytes 32, (err, token) =>
                    throw err if err
                    token   = token.toString 'hex'
                    subject ="Activate your cloudbrowser account"
                    confirmationMsg = "Please click on the link below to verify your email address.<br>" +
                    "<p><a href='#{appUrl}/activate/#{token}'>Activate your account</a></p>" +
                    "<p>If you have received this message in error and did not sign up for a cloudbrowser account," +
                    " click <a href='#{appUrl}/deactivate/#{token}'>not my account</a></p>"

                    @sendEmail user.getEmail(), subject, confirmationMsg, () =>
                        throw err if err

                        db.collection application.dbName, (err, collection) =>
                            throw err if err

                            hashPassword {password:password}, (result) =>
                                userRec =
                                    email   : user.getEmail()
                                    key     : result.key.toString('hex')
                                    salt    : result.salt.toString('hex')
                                    status  : 'unverified'
                                    token   : token
                                    ns      : user.getNameSpace()
                                collection.insert userRec, () ->
                                    callback()

            sendResetLink : (user, callback) ->
                db.collection application.dbName, (err, collection) =>
                    throw err if err
                    collection.findOne user.toJson(), (err, userRec) =>
                        throw err if err
                        if userRec
                            Crypto.randomBytes 32, (err, token) =>
                                throw err if err
                                token = token.toString 'hex'
                                esc_email = encodeURIComponent(userRec.email)
                                subject = "Link to reset your CloudBrowser password"
                                message = "You have requested to change your password." +
                                " If you want to continue click " +
                                "<a href='#{appUrl}/password_reset?token=#{token}&user=#{esc_email}'>reset</a>." +
                                " If you have not requested a change in password then take no action."

                                @sendEmail userRec.email, subject, message, () ->
                                    collection.update user.toJson(),
                                    {$set:{status:"reset_password",token:token}}, {w:1}, (err, result) ->
                                        throw err if err
                                        callback(true)

                        else callback(false)

            getResetEmail : (queryString) ->
                query = QueryString.parse(queryString)
                if query isnt "" then query = "?" + query
                return query['user']

            resetPassword : (queryString, password, callback) ->
                query = QueryString.parse(queryString)
                if query isnt "" then query = "?" + query
                db.collection application.dbName, (err, collection) =>
                    throw err if err
                    collection.findOne {email:query['user'], ns:'local'}, (err, userRec) =>
                        if userRec and userRec.status is "reset_password" and userRec.token is query['token']
                            collection.update {email:userRec.email, ns:userRec.ns},
                            {$unset: {token: "", status: ""}}, {w:1}, (err, result) =>
                                throw err if err
                                hashPassword {password:password}, (result) ->
                                    collection.update {email:userRec.email, ns:userRec.ns},
                                    {$set: {key: result.key.toString('hex'), salt: result.salt.toString('hex')}},
                                    (err, result) ->
                                        throw err if err
                                        callback(true)
                        else
                            callback(false)

module.exports = AuthenticationAPI
