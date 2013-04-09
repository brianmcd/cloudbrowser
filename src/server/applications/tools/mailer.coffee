nodemailer              = require("nodemailer")

window.sendEmail = (toEmailID, subject, message, callback) ->
    smtpTransport = nodemailer.createTransport "SMTP",
        service: "Gmail"
        auth:
            user: config.nodeMailerEmailID
            pass: config.nodeMailerPassword

    mailOptions =
        from: config.nodeMailerEmailID
        to: toEmailID
        subject: subject
        html: message

    smtpTransport.sendMail mailOptions, (error, response) ->
        if error then callback error
        callback null
        smtpTransport.close()

