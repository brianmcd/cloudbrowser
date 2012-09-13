inCloudBrowser = typeof (require) isnt 'undefined'

if not inCloudBrowser
    emailController = ($scope) ->
        $scope.sendmail = () ->
            window.alert "Sending email from client-side JavaScript?  You have to be kidding"
else
    emailController = ($scope) ->
        FS = require('fs')
        nodemailer = require('nodemailer')

        smtp = nodemailer.createTransport 'SMTP',
          service: 'Gmail'
          auth:
            user: 'cloud9browser@gmail.com'
            pass: FS.readFileSync('emailpass.txt', 'utf8')

        $scope.sendmail = () ->
          for p in $scope.model.participants when p.email isnt 'none'
            msg = "Hey #{p.name}, here are the available times:\n"
            msg += "\t#{time}\n" for start, time of $scope.model.possibleTimes()
            smtp.sendMail
              from: "CloudBrowser <cloud9browser@gmail.com>"
              to: p.email
              subject: "Available Meeting Times"
              text: msg

angular.module('doodleApp').controller 'doodleEmailController', emailController
