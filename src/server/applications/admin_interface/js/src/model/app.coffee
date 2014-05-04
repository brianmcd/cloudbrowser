camelCaseToWords = (camelCaseString) ->
    camelCaseString
        .replace(/([A-Z])/g, ' $1')
        .replace(/^./, (str) -> str.toUpperCase())

class App
    constructor : (appConfig, format) ->
        @url           = appConfig.getUrl()
        @api           = appConfig
        @name          = appConfig.getName()
        @description   = appConfig.getDescription()
        @mountPoint    = appConfig.getMountPoint()
        @isPublic      = appConfig.isAppPublic()
        @mounted       = appConfig.isMounted()
        @browserLimit  = appConfig.getBrowserLimit()
        @isAuthEnabled = appConfig.isAuthConfigured()
        @instantiationStrategy =
            camelCaseToWords(appConfig.getInstantiationStrategy())
        @userMgr        = new POJOListManager(User, 'emailID')
        @browserMgr     = new APIListManager(Browser, format)
        @appInstanceMgr = new APIListManager(AppInstance, format)
        # For the tables to be visible on load
        @userMgr.visible        = true
        @browserMgr.visible     = true
        @appInstanceMgr.visible = true

# Exporting
this.App = App
