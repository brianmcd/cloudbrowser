User            = require("./user")
Crypto          = require("crypto")
Nodemailer      = require("nodemailer")
QueryString     = require("querystring")
{LocalStrategy, GoogleStrategy} = require("./authentication_strategies")
{getMountPoint, hashPassword} = require("./utils")

# Usage : CloudBrowser.auth.APIMethod
#
# @method #logout()
#   Logs out all connected clients from this application.
#
# @method #sendEmail(toEmailID, subject, message, callback)
#   Sends an email to the specified user.
#   @param [String] toEmailID  The email ID of the user to whom the message must be sent.
#   @param [String] subject    The subject of the email.
#   @param [String] message    The content of the email.
#   @param [Function] callback No arguments are passed to the callback.
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

            localStrategy  : new LocalStrategy(bserver)

            googleStrategy : new GoogleStrategy(bserver)
            
module.exports = AuthenticationAPI
