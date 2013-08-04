Nodemailer        = require("nodemailer")

###*
    @class cloudbrowser.Util
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
        @memberOf cloudbrowser.Util
        @param {string} toEmailID
        @param {string} subject
        @param {string} message
        @param {emptyCallback} callback
    ###
    sendEmail : (toEmailID, subject, message, callback) ->
        if not _pvts[@_idx].emailerConfig.email or
        not _pvts[@_idx].emailerConfig.password
            throw new Error("Please provide an email ID and the corresponding" +
            " password in emailer_config.json to enable sending confirmation emails")

        smtpTransport = Nodemailer.createTransport "SMTP",
            service: "Gmail"
            auth:
                user: _pvts[@_idx].emailerConfig.email
                pass: _pvts[@_idx].emailerConfig.password

        mailOptions =
            from    : _pvts[@_idx].emailerConfig.email
            to      : toEmailID
            subject : subject
            html    : message

        smtpTransport.sendMail mailOptions, (err, response) ->
            throw err if err
            smtpTransport.close()
            callback()

module.exports = Util
