nodemailer              = require("nodemailer")

window.sendEmail = (toEmailID, subject, message, fromEmailID, fromPassword, callback) ->
    smtpTransport = nodemailer.createTransport "SMTP",
        service: "Gmail"
        auth:
            user: fromEmailID
            pass: fromPassword

    mailOptions =
        from: fromEmailID
        to: toEmailID
        subject: subject
        html: message

    smtpTransport.sendMail mailOptions, (error, response) ->
        if error then callback error
        callback null
        smtpTransport.close()

