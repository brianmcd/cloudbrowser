(function() {
  var nodemailer;

  nodemailer = require("nodemailer");

  window.sendEmail = function(toEmailID, subject, message, fromEmailID, fromPassword, callback) {
    var mailOptions, smtpTransport;
    smtpTransport = nodemailer.createTransport("SMTP", {
      service: "Gmail",
      auth: {
        user: fromEmailID,
        pass: fromPassword
      }
    });
    mailOptions = {
      from: fromEmailID,
      to: toEmailID,
      subject: subject,
      html: message
    };
    return smtpTransport.sendMail(mailOptions, function(error, response) {
      if (error) callback(error);
      callback(null);
      return smtpTransport.close();
    });
  };

}).call(this);
