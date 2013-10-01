Passport = require('passport')
Strategy = require('passport-google').Strategy

class GoogleStrategy
    @_configure : (config) ->
        # Configure the google strategy with 
        # 1. The url to return to after successful authentication
        # 2. The domain of the server
        # 3. A validate callback that calls done() with the user constructed from the information
        # returned by google
        Passport.use new Strategy
            returnURL : "http://#{config.domain}:#{config.port}/checkauth"
            realm     : "http://#{config.domain}:#{config.port}"
        , (identifier, profile, done) =>
            # validate callback
            done null,
                identifier  : identifier
                email       : profile.emails[0].value
                displayName : profile.displayName

        Passport.serializeUser (user, done) ->
            done(null, user.identifier)

        Passport.deserializeUser (identifier, done) ->
            done(null, {identifier:identifier})

    @_getRedirectUrl : (session) ->
        if session.redirectto?
            redirectto = session.redirectto
            session.redirectto = null
            session.save()
        else
            # Default is to redirect to the mountPoint of the application
            redirectto = session.mountPoint
        return redirectto

    @_successfulAuth : (app, req, res, servers) ->
        # Check if the client needs to be redirected to some virtual browser
        # after authentication
        redirectto = @_getRedirectUrl(req.session)
        newUser =
            email : req.user.email
            ns    : 'google'

        app.addNewUser newUser, (err, user) ->
            servers.http.redirect(res, redirectto)
            servers.http.updateSession(req, user, req.session.mountPoint)

    @_setupRoutes : (servers) ->
        # When the client requests for /googleAuth, the google authentication
        # procedure begins
        servers.express.get '/googleAuth', Passport.authenticate('google')

        # This is the URL google redirects the client to after authentication
        servers.express.get '/checkauth', Passport.authenticate('google'), (req, res) =>
            # Invalid requests, that did not originate from cloudbrowser
            if not req.session.mountPoint then res.send(403)

            app = servers.cloudbrowser.applications.find(req.session.mountPoint)
            if not app?
                res.send(403)

            # Authentication unsuccessful
            else if not req.user
                servers.http.redirect(res, req.session.mountPoint)

            # Authentication successful
            else
                @_successfulAuth(app, req, res, servers)

    @setup : (config, servers) ->
        @_configure(config)
        @_setupRoutes(servers)

module.exports = GoogleStrategy
