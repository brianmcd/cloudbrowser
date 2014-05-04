Nodemailer        = require("nodemailer")
cloudbrowserError = require("../shared/cloudbrowser_error")

###*
    @class Util
    @param {object} emailerConfig
###
class Util
    _pvts = []
    _instance = null

    constructor : (emailerConfig) ->
        # Singleton
        if _pvts.length then return _instance
        else _instance = this

        # Defining @_idx as a read-only property
        Object.defineProperty this, "_idx",
            value : _pvts.length

        # Setting private properties
        _pvts.push
            emailerConfig : emailerConfig

        Object.freeze(this.__proto__)
        Object.freeze(this)
    ###*
        Sends an email to the specified user.
        @static
        @method sendEmail
        @memberOf Util
        @param {Object} options
        @param {String} options.to
        @param {String} options.subject
        @param {String} options.html
        @param {errorCallback} callback
    ###
    sendEmail : (options) ->
        {callback} = options
        if not _pvts[@_idx].emailerConfig
            callback?(cloudbrowserError('NO_EMAIL_CONFIG'))
            return
        
        {email, password} = _pvts[@_idx].emailerConfig

        if not (email and password)
            callback?(cloudbrowserError('NO_EMAIL_CONFIG'))
            return

        smtpTransport = Nodemailer.createTransport "SMTP",
            service: "Gmail"
            auth: {user : email, pass : password}

        options.from = email

        smtpTransport.sendMail options, (err, response) ->
            smtpTransport.close()
            callback?(err)

module.exports = Util
