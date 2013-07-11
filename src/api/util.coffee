Nodemailer        = require("nodemailer")

###*
    @class cloudbrowser.Util
    @param {object} config
###
class Util
    _privates = []
    _instance = null

    constructor : (config) ->
        # Singleton
        if _privates.length then return _instance
        else _instance = this

        # Defining @_index as a read-only property
        Object.defineProperty this, "_index",
            value : _privates.length

        # Setting private properties
        _privates.push
            config : config

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
        if not _privates[@_index].config.emailerConfig.email or
        not _privates[@_index].config.emailerConfig.password
            throw new Error "Please provide an email and the corresponding password" +
            " to enable sending confirmation emails in emailer_config.json"

        smtpTransport = Nodemailer.createTransport "SMTP",
            service: "Gmail"
            auth:
                user: _privates[@_index].config.emailerConfig.email
                pass: _privates[@_index].config.emailerConfig.password

        mailOptions =
            from    : _privates[@_index].config.emailerConfig.email
            to      : toEmailID
            subject : subject
            html    : message

        smtpTransport.sendMail mailOptions, (err, response) ->
            throw err if err
            smtpTransport.close()
            callback()

module.exports = Util
