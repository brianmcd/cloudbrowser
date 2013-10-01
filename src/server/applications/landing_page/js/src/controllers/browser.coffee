NwGlobal = require('nwglobal')
Async    = require('async')

# Cloudbrowser API objects
curVB     = cloudbrowser.currentVirtualBrowser
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

        $scope.remove = () ->
            #$scope.closeBox('confirmDelete')
            $scope.browser.api.close (err) ->
                if err then $scope.safeApply -> $scope.setError(err)
                
        # Local functions
        ###
        checkPermission = (type, callback) ->
            Async.detect $scope.selected, (browser, callback) ->
                browser.api.checkPermissions type, (err, hasPermission) ->
                    if err then $scope.safeApply () ->
                        $scope.error = err.message
                    else callback(not hasPermission)
            , (permissionDenied) -> callback(not permissionDenied)


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
        $scope.clickRename = () ->
            browser.api.isOwner creator, (err, isOwner) ->
                $scope.safeApply ->
                    if err then $scope.setError(err)
                    if isOwner then $scope.safeApply -> browser.editing = true

        $scope.isEditing = () -> return browser.editing

        $scope.rename = () -> browser.editing = true

        $scope.getURL = () -> return browser.api.getURL()

        # Event Handlers
        browser.api.addEventListener 'share', () ->
            Async.waterfall NwGlobal.Array(
                (next) ->
                    browser.api.getOwners(next)
                (owners, next) ->
                    $scope.safeApply -> browser.owners = format.toJson(owners)
                    browser.api.getReaderWriters(next)
            ), (err, readerWriters) ->
                $scope.safeApply () ->
                    if err then $scope.setError(err)
                    else browser.collaborators = format.toJson(readerWriters)

        browser.api.addEventListener 'rename', (name) =>
            $scope.safeApply -> browser.name = name
]
