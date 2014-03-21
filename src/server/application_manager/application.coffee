Path     = require('path')
Fs       = require('fs')
Async    = require('async')

User     = require('../user')
{hashPassword}     = require('../../api/utils')
cloudbrowserError  = require('../../shared/cloudbrowser_error')
BaseApplication = require('./base_application')
AuthApp = require('./authenticate_application')
LandingApplication = require('./landing_application')
PasswordRestApplication = require('./pwd_reset_application')
routes = require('./routes')


###
_validDeploymentConfig :
    isPublic                : bool - "Should the app be listed as a publicly visible app"
    owner                   : str  - "Owner of the application in this deployment"
    collectionName          : str  - "Name of db collection for this app"
    mountOnStartup          : bool - "Should the app be mounted on server start"
    authenticationInterface : bool - "Enable authentication"
    mountPoint   : str - "The url location of the app"
    description  : str - "Text describing the application."
    browserLimit : num - "Cap on number of browsers per user. Only for multiInstance."

_validAppConfig :
    entryPoint   : str - "The location of the html file of the the single page app"
    instantiationStrategy : str - "Strategy for the instantiation of browsers"
    applicationStateFile    : str  - "Location of the file that contains app state"
###

class Application extends BaseApplication

    constructor : (config, @server) ->
        super(config, @server)
        if @isMultiInstance() or @isSingleInstancePerUser() or @isAuthConfigured()
            @authApp = new AuthApp(this)
            @addSubApp(@authApp)
            pwdRestApp = new PasswordRestApplication(this)
            @addSubApp(pwdRestApp)
        if @isMultiInstance()
            @landingPageApp = new LandingApplication(this)
            @addSubApp(@landingPageApp)
            
        
    mount : () ->
        if @subApps?
            for subApp in @subApps
                subApp.mount()
        if @authApp?
            @authApp.mountAuthForParent()
        else
            @httpServer.mount(@mountPoint, @mountPointHandler)
            @httpServer.mount(routes.concatRoute(@mountPoint,routes.browserRoute),
                @serveVirtualBrowserHandler)
            @httpServer.mount(routes.concatRoute(@mountPoint, routes.resourceRoute),
                @serveResourceHandler)
        @mounted = true
                    


    addSubApp : (subApp) ->
        if not @subApps?
            @subApps = []
        @subApps.push(subApp)

    isStandalone : () ->
        return true
        


module.exports = Application
