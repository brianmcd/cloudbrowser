Nodemailer        = require("nodemailer")

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
        @param {string} toEmailID
        @param {string} subject
        @param {string} message
        @param {emptyCallback} callback
    ###
    sendEmail : (toEmailID, subject, message, callback) ->
        smtpTransport = Nodemailer.createTransport "SMTP",
            service: "Gmail"
            auth:
                user: _privates[@_index].config.nodeMailerEmailID
                pass: _privates[@_index].config.nodeMailerPassword

        mailOptions =
            from    : _privates[@_index].config.nodeMailerEmailID
            to      : toEmailID
            subject : subject
            html    : message

        smtpTransport.sendMail mailOptions, (err, response) ->
            throw err if err
            smtpTransport.close()
            callback()

module.exports = Util
