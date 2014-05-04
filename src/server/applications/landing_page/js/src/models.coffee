managers = angular.module('CBLandingPage.models', ['CBLandingPage.services'])

managers.factory 'cb-appInstanceManager', ['cb-format', (format) ->
        return new AppInstanceManager(format)
]
