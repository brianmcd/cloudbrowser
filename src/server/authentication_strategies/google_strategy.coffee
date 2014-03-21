Passport = require('passport')
Strategy = require('passport-google').Strategy

class GoogleStrategy
    @configure : (config) ->
        # Configure the google strategy with 
        # 1. The url to return to after successful authentication
        # 2. The domain of the server
        # 3. A validate callback that calls done() with the user constructed from the information
        # returned by google
        Passport.use new Strategy
            returnURL : "http://#{config.getHttpAddr()}/checkauth"
            realm     : "http://#{config.getHttpAddr()}"
        , (identifier, profile, done) ->
            done(null, {email : profile.emails[0].value})

        # These two methods are for use with persistent sessions
        # So now, on the session there will be an object of the form
        # passport : {user : <email>}
        Passport.serializeUser (user, done) ->
            done(null, user.email)

        Passport.deserializeUser (email, done) ->
            done(null, {email : email})

module.exports = GoogleStrategy
