helpers = angular.module('CBLandingPage.services', [])

helpers.service 'cb-mail', () ->
    s = {
        send : (options) ->
            {from, to, sharedObj, url, mountPoint, callback} = options
            sub = "CloudBrowser - #{from} shared #{sharedObj} with you."
            msg = "Hi #{to}<br>To view it, visit <a href='#{url}'>"+
                  "#{mountPoint}</a> and login to your existing account" +
                  " or use your google ID to login if you do not have an"+
                  " account already."
            cloudbrowser.util.sendEmail
                to       : to
                html     : msg
                subject  : sub
                callback : callback
    }
    return s


helpers.service 'cb-format', () ->
    months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    this.date = (date) ->
        if not date instanceof Date then return null
        month       = months[date.getMonth()]
        day         = date.getDate()
        year        = date.getFullYear()
        ###
        hours       = date.getHours()
        timeSuffix  = if hours < 12 then 'am' else 'pm'
        hours       = hours % 12
        hours       = if hours then hours else 12
        minutes     = date.getMinutes()
        minutes     = if minutes > 10 then minutes else '0' + minutes
        time        = hours + ":" + minutes + " " + timeSuffix
        date        = day + " " + month + " " + year + " (" + time + ")"
        ###
        date        = day + " " + month + " " + year
        return date
