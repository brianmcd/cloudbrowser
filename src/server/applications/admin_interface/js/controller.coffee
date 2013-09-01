CBAdmin = angular.module("CBAdmin", [])

CBAdmin.controller "AppCtrl", ($scope) ->

    $scope.safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase is '$apply' or phase is '$digest'
            if fn then fn()
        else
            this.$apply(fn)

    $scope.apps = []

    class App
        @camelCaseToWords : (camelCaseString) ->
            camelCaseString
                .replace(/([A-Z])/g, ' $1')
                .replace(/^./, (str) -> str.toUpperCase())

        @add : (appConfig) ->
            app =
                url           : appConfig.getUrl()
                api           : appConfig
                description   : appConfig.getDescription()
                mountPoint    : appConfig.getMountPoint()
                isPublic      : appConfig.isAppPublic()
                mounted       : appConfig.isMounted()
                browserLimit  : appConfig.getBrowserLimit()
                isAuthEnabled : appConfig.isAuthConfigured()
                instantiationStrategy :
                    App.camelCaseToWords(appConfig.getInstantiationStrategy())

            appConfig.getUsers (err, users) ->
                if err then console.log(err)
                else $scope.safeApply -> app.users = users

            appConfig.getVirtualBrowsers (err, virtualBrowsers) ->
                if err then console.log(err)
                else $scope.safeApply -> app.virtualBrowsers = virtualBrowsers

            App.setupEventListeners(app)

            $scope.apps.push(app)

        @remove : (mountPoint) ->
            for app in $scope.apps when app.mountPoint is mountPoint
                idx = $scope.apps.indexOf(app)
                return $scope.apps.splice(idx, 1)

        # For virtual browser related events
        @setupEventListeners : (app) ->
            app.api.addEventListener "added", (vb) ->
                $scope.safeApply -> app.virtualBrowsers.push(vb)

            app.api.addEventListener "removed" , (vbID) ->
                $scope.safeApply ->
                    for vb in app.virtualBrowsers when vb.id is vbID
                        idx = app.virtualBrowsers.indexOf(vb)
                        app.virtualBrowsers.splice(idx, 1)


    # API objects
    curVB        = cloudbrowser.currentVirtualBrowser
    serverConfig = cloudbrowser.serverConfig

    # Application related events
    serverConfig.addEventListener "added", (appConfig) ->
        App.add(appConfig)

    serverConfig.addEventListener "removed", (appConfig) ->
        App.remove(appConfig)

    # File uploader Component
    fileUploaderDiv = document.getElementById('file-uploader')
    fileUploader    = curVB.createComponent 'fileUploader',
        fileUploaderDiv,
            form :
                action : "#{serverConfig.getUrl()}/gui-deploy"
                class  : "form-inline well"
                enctype : "multipart/form-data"
            legend : "Upload an Application"
            inputSubmit :
                name  : "Upload"
                class : "btn btn-primary"
            inputText :
                placeholder : "App Name"
                style : "margin-right: 10px"
                name  : "appName"
            inputFile :
                accept : "application/x-gzip"
                name   : "newApp"

    # Initialization
    $scope.user = curVB.getCreator()
    $scope.selectedApp = null

    # Loading all the apps
    serverConfig.listApps
        filters : {perUser : true}
        callback : (err, appConfigs) ->
            if err then console.log err
            else $scope.safeApply ->
                App.add(appConfig) for appConfig in appConfigs
                # Select the first app initially
                if $scope.apps.length then $scope.safeApply ->
                    $scope.selectedApp = $scope.apps[0]

    # Methods on the angular scope
    $scope.leftClick = (url) -> curVB.redirect(url)

    $scope.editDescription = (app) ->
        app.api.isOwner $scope.user, (err, isOwner) ->
            if isOwner then $scope.safeApply -> app.editing = true

    $scope.getBoxClass = (app) ->
        if not app then return
        if app.mounted is true then return "mounted"
        else return "disabled"

    toggle = (app, property, method1, method2) ->
        if app[property] then app.api[method1] (err) ->
            if err then console.log(err)
            else $scope.safeApply -> app[property] = false
        else app.api[method2] (err) ->
            if err then console.log(err)
            else $scope.safeApply -> app[property] = true

    $scope.toggleMountDisable = (app) ->
        toggle(app, 'mounted', 'disable', 'mount')

    $scope.togglePrivacy = (app) ->
        toggle(app, 'isPublic', 'makePrivate', 'makePublic')

    $scope.toggleAuthentication = (app) ->
        toggle(app, 'isAuthEnabled', 'disableAuthentication',
            'enableAuthentication')

    $scope.selectApp = (app) -> $scope.selectedApp = app
    
    $scope.getAppClass = (app) ->
        if $scope.selectedApp is app then return "selected"
        else return ""

    $scope.logout = () -> cloudbrowser.auth.logout()

    $scope.sortBy = (predicate) ->
        $scope.predicate = predicate
        reverseProp = "#{predicate}-reverse"
        $scope[reverseProp] = not $scope[reverseProp]
        $scope.reverse = $scope[reverseProp]

CBAdmin.filter "removeSlash", () ->
    return (input) ->
        if not input then return
        if input is "/" then return "Home Page"
        else return input.substring(1)

CBAdmin.directive 'ngHasfocus', () ->
    return (scope, element, attrs) ->
        scope.$watch attrs.ngHasfocus, (nVal, oVal) ->
            if (nVal)
                element[0].focus()
        element.bind 'blur', () ->
            scope.$apply(
                attrs.ngHasfocus + " = false"
                scope.selectedApp.api.setDescription(scope.selectedApp.description)
            )
        element.bind 'keydown', (e) ->
            if e.which is 13
                scope.$apply(
                    attrs.ngHasfocus + " = false"
                    scope.selectedApp.api.setDescription(scope.selectedApp.description)
                )
