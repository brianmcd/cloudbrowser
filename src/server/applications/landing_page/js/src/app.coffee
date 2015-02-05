CBLandingPage = angular.module('CBLandingPage', [
        'CBLandingPage.models'
        'CBLandingPage.filters',
        'CBLandingPage.services',
        'CBLandingPage.directives',
        'CBLandingPage.controllers.app',
        'CBLandingPage.controllers.appInstance',
        'CBLandingPage.controllers.browser'
    ]
).config(($sceDelegateProvider) ->
  $sceDelegateProvider.resourceUrlWhitelist([
    # Allow same origin resource loads.
    'self',
    # loading templates from file system
    "file://"
  ])
)
