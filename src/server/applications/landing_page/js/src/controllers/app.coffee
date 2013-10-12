Path     = require('path')
Async    = require('async')
NwGlobal = require('nwglobal')


app = angular.module('CBLandingPage.controllers.app',
    ['CBLandingPage.services', 'CBLandingPage.models'])

# Cloudbrowser API objects
curVB     = cloudbrowser.currentBrowser
creator   = curVB.getCreator()
appConfig = curVB.getAppConfig()

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
        # Templates used in the view
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

        # The following CRUD methods are attached to the scope to ensure
        # prototypal inheritance and thus enable their use by child scopes
        $scope.addAppInstance = (appInstanceConfig) ->
            appInstance = appInstanceMgr.find(appInstanceConfig.getID())
            if appInstance then return appInstance

            appInstance = appInstanceMgr.add(appInstanceConfig)
            $scope.$apply()

            Async.waterfall NwGlobal.Array(
                (next) ->
                    appInstance.owner = appInstance.api.getOwner().toJson()
                    appInstance.api.isAssocWithCurrentUser(next)
                (isAssoc, next) ->
                    if isAssoc then appInstance.api.getReaderWriters(next)
                    else next(null, null)
                (collaborators, next) ->
                    if collaborators then $scope.safeApply ->
                        appInstance.collaborators = format.toJson(collaborators)
                    next(null)
            ), (err) ->
                if err then $scope.safeApply -> $scope.setError(err)

            return appInstance

        $scope.updateBrowserCollaborators = (browser, callback) ->
            Async.waterfall NwGlobal.Array(
                (next) ->
                    browser.api.getOwners(next)
                (owners, next) ->
                    $scope.safeApply -> browser.owners = format.toJson(owners)
                    browser.api.getReaderWriters(next)
                (collaborators, next) ->
                    $scope.safeApply -> browser.collaborators = format.toJson(collaborators)
                    next(null)
            ), callback

        $scope.addBrowser = (browserConfig, appInstance) ->
            browser = null
            Async.waterfall NwGlobal.Array(
                (next) ->
                    # Add the app instance to the view if not already present
                    if not appInstance
                        appInstanceConfig = browserConfig.getAppInstanceConfig()
                        appInstance = $scope.addAppInstance(appInstanceConfig)
                    $scope.safeApply () ->
                        # Then add the browser to the app instance
                        browser = appInstance.browserMgr.add(browserConfig)
                        appInstance.showOptions = true
                    # Set the collaborators
                    $scope.updateBrowserCollaborators(browser, next)
            ), (err) ->
                $scope.safeApply ->
                    if err then $scope.setError(err)
                    appInstance.processing = false

        $scope.removeBrowser = (browserID) ->
            for appInstance in appInstanceMgr.items
                # This will remove it from only that appInstance that has the
                # browser with ID = browserID. Other appInstances will ignore
                # the request
                $scope.safeApply -> appInstance.browserMgr.remove(browserID)

        $scope.removeAppInstance = (appInstanceID) ->
            $scope.safeApply -> appInstanceMgr.remove(appInstanceID)

        # Properties used in the view
        $scope.description  = appConfig.getDescription()
        $scope.mountPoint   = appConfig.getMountPoint()
        $scope.filterType   = 'all'
        $scope.appInstances = appInstanceMgr.items
        $scope.appInstanceName = appConfig.getAppInstanceName()
        # TODO remove freeze on user api
        $scope.user =
            email : creator.getEmail()
            ns    : creator.getNameSpace()

        # Methods used in the view
        $scope.logout   = () ->
            cloudbrowser.auth.logout()

        $scope.create = () ->
            Async.waterfall NwGlobal.Array(
                (next) ->
                    appConfig.createAppInstance(next)
            ), (err, appInstanceConfig) ->
                if err then $scope.safeApply () -> $scope.setError(err)
                else $scope.addAppInstance(appInstanceConfig)

        # Event handlers that keep all browsers of the application in sync
        appConfig.addEventListener('addBrowser', $scope.addBrowser)
        appConfig.addEventListener('removeBrowser', $scope.removeBrowser)
        appConfig.addEventListener('addAppInstance', $scope.addAppInstance)
        appConfig.addEventListener('removeAppInstance', $scope.removeAppInstance)

        # Populate appInstances and browsers at startup
        appConfig.getBrowsers (err, browserConfigs) ->
            if err then $scope.safeApply -> $scope.setError(err)
            $scope.addBrowser(browserConfig) for browserConfig in browserConfigs

        appConfig.getAppInstances (err, appInstanceConfigs) ->
            $scope.addAppInstance(appInstanceConfig) for appInstanceConfig in appInstanceConfigs
]
