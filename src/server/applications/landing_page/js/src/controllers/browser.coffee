NwGlobal = require('nwglobal')
Async    = require('async')

# Cloudbrowser API objects
curVB     = cloudbrowser.currentBrowser
creator   = curVB.getCreator()
appConfig = curVB.getAppConfig()

app = angular.module('CBLandingPage.controllers.browser',
    [
        'CBLandingPage.services',
        'CBLandingPage.models'
    ]
)

app.controller 'BrowserCtrl', [
    '$scope'
    'cb-mail'
    'cb-format'
    ($scope, mail, format) ->
        {browser} = $scope

        $scope.error = {}
        $scope.success = {}

        $scope.redirect = () -> browser.redirect()

        # Local functions
        ###
        # Filter operations
        $scope.sortBy = (predicate) ->
            $scope.predicate = predicate
            reverseProperty = "#{predicate}-reverse"
            $scope[reverseProperty] = not $scope[reverseProperty]
            $scope.reverse = $scope[reverseProperty]

        $scope.showUpArrow = (predicate) ->
            return $scope.predicate is predicate and
            not $scope["#{predicate}-reverse"]
                            
        $scope.showDownArrow = (predicate) ->
            return $scope.predicate is predicate and
            $scope["#{predicate}-reverse"]
        ###
            
        # Operation on browser
        $scope.isEditing = () -> return browser.editing

        $scope.rename = () ->
            Async.waterfall NwGlobal.Array(
                (next) ->
                    browser.api.isOwner(creator, next)
            ), (err, isOwner) ->
                $scope.safeApply ->
                    if err then $scope.$parent.setError(err)
                    if isOwner then browser.editing = true
                    else $scope.$parent.setError(new Error("Permission Denied"))

        $scope.getURL = () -> return browser.api.getURL()

        # Event Handlers
        browser.api.addEventListener 'share', () ->
            $scope.updateBrowserCollaborators browser, (err) ->
                if err then $scope.safeApply -> $scope.$parent.setError(err)

        browser.api.addEventListener 'rename', (name) =>
            $scope.safeApply -> browser.name = name
]
