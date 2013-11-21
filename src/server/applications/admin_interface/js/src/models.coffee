model = angular.module('CBAdminInterface.models', ['CBAdminInterface.services'])

model.factory 'cb-appManager', ['cb-format', (format) ->
        return new AppManager(App, format)
]
