Path = require('path')

app = angular.module('CBLandingPage.controllers.app',
    [
        'CBLandingPage.services',
        'CBLandingPage.models'
    ]
)

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

# Cloudbrowser API objects
curVB     = cloudbrowser.currentVirtualBrowser
creator   = curVB.getCreator()
appConfig = curVB.getAppConfig()

app.controller 'AppCtrl', [
    '$scope'
    'cb-browserManager'
    'cb-sharedStateManager'
    ($scope, browserManager, sharedStateManager) ->
        # Scope variables
        $scope.templates =
            header           : "header.html"
            initial          : "initial.html"
            browserTable     : "browser_table.html"
            sharedStateTable : "shared_state_table.html"
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
                shareSharedState  : "buttons/share_shared_state.html"
                removeSharedState : "buttons/remove_shared_state.html"

        appDir = Path.resolve(process.cwd(), "src/server/applications/landing_page")
        for name, path of $scope.templates
            if typeof path is "string"
                $scope.templates[name] = "#{appDir}/partials/#{path}"
            else for k, v of path
                path[k] = "#{appDir}/partials/#{v}"

        $scope.description = appConfig.getDescription()
        $scope.mountPoint  = appConfig.getMountPoint()
        $scope.filterType  = 'all'
        $scope.user =
            email : creator.getEmail()
            ns    : creator.getNameSpace()

        $scope.logout   = () -> cloudbrowser.auth.logout()
        $scope.filterBy = (property) -> $scope.filterType = property

        # The view depends on whether the app has shared state enabled or not
        sharedStateName = appConfig.getSharedStateName()

        if not sharedStateName
            $scope.entityName = 'browser'
            $scope.templates.entity = $scope.templates.browserTable
            $scope.entity = $scope.browsers = browsers = browserManager.browsers
            $scope.create = () -> browserManager.create()
            appConfig.getVirtualBrowsers (err, browserConfigs) ->
                $scope.safeApply ->
                    if err then $scope.setError(err)
                    else for browserConfig in browserConfigs
                        browserManager.add(browserConfig)
            appConfig.addEventListener 'add', (browserConfig) ->
                $scope.safeApply -> browserManager.add(browserConfig, $scope)
            appConfig.addEventListener 'remove', (id) ->
                $scope.safeApply -> browserManager.remove(id)
        else
            $scope.entityName = sharedStateName
            $scope.templates.entity = $scope.templates.sharedStateTable
            $scope.entity = $scope.sharedStates = sharedStateManager.sharedStates
            $scope.create = () -> sharedStateManager.create($scope)
]
