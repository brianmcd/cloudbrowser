app = angular.module('CBLandingPage.controllers.app',
    ['CBLandingPage.services', 'CBLandingPage.models'])

# Cloudbrowser API objects
curVB     = cloudbrowser.currentBrowser
appConfig = cloudbrowser.parentAppConfig

app.run ($rootScope) ->
    # A replacement to $apply that calls digest only if
    # not already in a digest cycle
    $rootScope.safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase == '$apply' or phase == '$digest'
            if fn then fn()
        else this.$apply(fn)

    $rootScope.error = {}

    $rootScope.setError = (error) ->
        this.error.message = error.message

app.controller 'AppCtrl', [
    '$scope'
    'cb-appInstanceManager'
    'cb-format'
    ($scope, appInstanceMgr, format) ->
        # Path to templates used in the view
        $scope.templates =
            header           : "header.html"
            initial          : "initial.html"
            browserTable     : "browser_table.html"
            appInstanceTable : "app_instance_table.html"
            forms :
                addCollaborator   : "forms/add_collaborator.html"
            messages :
                error             : "messages/error.html"
                success           : "messages/success.html"
                confirmDelete     : "messages/confirm_delete.html"
            buttons :
                create            : "buttons/create.html"
                filter            : "buttons/filter.html"
                showLink           : "buttons/show_link.html"
                addBrowser        : "buttons/add_browser.html"
                expandCollapse    : "buttons/expand_collapse.html"
                shareAppInstance  : "buttons/share_app_instance.html"
                removeAppInstance : "buttons/remove_app_instance.html"

        for name, path of $scope.templates
            if typeof path is "string"
                $scope.templates[name] = "#{__dirname}/partials/#{path}"
            else for k, v of path
                path[k] = "#{__dirname}/partials/#{v}"

        $scope.addBrowser = (browserConfig, appInstanceConfig) ->
            # Don't add the browsers if you're just the owner of the app
            browserConfig.getUserPrevilege((err, result)->
                return $scope.setError(err) if err?
                return if not result
                appInstance = appInstanceMgr.add(appInstanceConfig)
                # Then add the browser to the app instance
                browser = appInstance.browserMgr.add(browserConfig)
                appInstance.showOptions = true
                appInstance.processing = false
                $scope.safeApply ->
                )
            

        $scope.removeBrowser = (browserID) ->
            for appInstance in appInstanceMgr.items
                appInstance.browserMgr.remove(browserID)
            $scope.safeApply ->

        $scope.removeAppInstance = (appInstanceID) ->
            appInstanceMgr.remove(appInstanceID)

        # Properties used in the view
        $scope.description  = appConfig.getDescription()
        $scope.mountPoint   = appConfig.getMountPoint()
        $scope.name         = appConfig.getName()
        $scope.appInstances = appInstanceMgr.items
        $scope.user = curVB.getCreator()
        $scope.appInstanceName = appConfig.getAppInstanceName()
        $scope.filter =
            browsers     : 'all'
            appInstances : 'all'

        # Methods used in the view
        $scope.logout   = () ->
            cloudbrowser.auth.logout()

        $scope.create = () ->
            appConfig.createAppInstance (err, appInstanceConfig) ->
                $scope.safeApply () ->
                    if err then $scope.setError(err)
                    else addAppInstanceConfig(appInstanceConfig)

        # Event handlers that keep all browsers of the application in sync
        
        appConfig.addEventListener 'addAppInstance', (appInstanceConfig) ->
            $scope.safeApply -> appInstanceMgr.add(appInstanceConfig)
        appConfig.addEventListener 'shareAppInstance', (appInstanceConfig) ->
            $scope.safeApply -> appInstanceMgr.add(appInstanceConfig)
        appConfig.addEventListener 'removeAppInstance', (appInstanceID) ->
            $scope.safeApply -> $scope.removeAppInstance(appInstanceID)

        # Populate appInstances and browsers at startup
        

        addAppInstanceConfig = (appInstanceConfig)->
            appInstanceMgr.add(appInstanceConfig)
            appInstanceConfig.addEventListener('addBrowser', (browserConfig)->
                $scope.addBrowser(browserConfig, appInstanceConfig)
                )
            appInstanceConfig.addEventListener('shareBrowser',(browserConfig)->
                $scope.addBrowser(browserConfig, appInstanceConfig)
                )
            appInstanceConfig.addEventListener('removeBrowser',(id)->
                $scope.removeBrowser(id, appInstanceConfig)
                )
            appInstanceConfig.getAllBrowsers((err, browserConfigs)->
                $scope.setError(err) if err?
                for browserConfig in browserConfigs
                    $scope.addBrowser(browserConfig, appInstanceConfig)
                )

        appConfig.getAppInstances (err, appInstanceConfigs) ->
            $scope.safeApply ->
                for appInstanceConfig in appInstanceConfigs
                    addAppInstanceConfig(appInstanceConfig)
]
