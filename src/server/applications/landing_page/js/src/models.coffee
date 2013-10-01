managers = angular.module('CBLandingPage.models', ['CBLandingPage.services'])

managers.factory 'cb-sharedStateManager', [
    '$rootScope'
    'cb-format'
    ($rootScope, format) ->
        return new SharedStateManager($rootScope, format)
]

managers.factory 'cb-browserManager', [
    '$rootScope'
    'cb-format'
    ($rootScope, format) ->
        return new BrowserManager($rootScope, format)
]
