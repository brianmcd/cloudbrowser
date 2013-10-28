CBAdmin = angular.module("CBAdmin", [])

CBAdmin.controller "AppCtrl", ($scope) ->

    $scope.safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase is '$apply' or phase is '$digest'
            if fn then fn()
        else
            this.$apply(fn)
    
    # Must create directive instead
    $scope.setError = (err) ->
        $scope.error = err
        setTimeout () ->
            $scope.safeApply -> $scope.error = null
        , 5000

    $scope.apps = []

    class App
        @camelCaseToWords : (camelCaseString) ->
            camelCaseString
                .replace(/([A-Z])/g, ' $1')
                .replace(/^./, (str) -> str.toUpperCase())

        @add : (appConfig) ->
            for app in $scope.apps
                if app.mountPoint is appConfig.getMountPoint()
                    return
            app =
                url           : appConfig.getUrl()
                api           : appConfig
                name          : appConfig.getName()
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
                else $scope.safeApply -> app.numUsers = users.length

            appConfig.getBrowsers (err, browsers) ->
                if err then console.log(err)
                else $scope.safeApply -> app.numBrowsers = browsers.length

            App.setupEventListeners(app)

            $scope.apps.push(app)

        @remove : (mountPoint) ->
            for app in $scope.apps when app.mountPoint is mountPoint
                idx = $scope.apps.indexOf(app)
                return $scope.apps.splice(idx, 1)

        # For browser related events
        @setupEventListeners : (app) ->
            app.api.addEventListener "addBrowser", (vb) ->
                $scope.safeApply -> app.numBrowsers++

            app.api.addEventListener "removeBrowser" , (vbID) ->
                $scope.safeApply -> app.numBrowsers--

            app.api.addEventListener "addUser", (user) ->
                $scope.safeApply -> app.numUsers++

            app.api.addEventListener "removeUser", (user) ->
                $scope.safeApply -> app.numUsers--

    # API objects
    curVB        = cloudbrowser.currentBrowser
    serverConfig = cloudbrowser.serverConfig

    # Application related events
    serverConfig.addEventListener "addApp", (appConfig) ->
        if appConfig.isOwner() then App.add(appConfig)

    serverConfig.addEventListener "removeApp", (appConfig) ->
        App.remove(appConfig)

    # File uploader Component
    fileUploader = curVB.createComponent 'fileUploader',
        document.getElementById('file-uploader'),
            legend      : "Upload an Application"
            formClass   : "form-inline well"
            buttonClass : "btn btn-primary"
    fileUploader.addEventListener "cloudbrowser.upload", (event) ->
        {user, file} = event.info
        # Anybody can post to the upload url.
        # But only posts by the current user will be accepted.
        if user isnt $scope.user then return
        if file.type isnt "application/x-gzip"
            $scope.safeApply -> $scope.setError("File must be a gzipped tarball")
            return
        serverConfig.uploadAndCreateApp file.path, (err, appConfig) ->
            $scope.safeApply ->
                if err then $scope.setError(err)
                else App.add(appConfig)
        
    # Initialization
    $scope.user = curVB.getCreator()
    $scope.selectedApp = null

    # Loading all the apps
    serverConfig.listApps
        filters : ['perUser']
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
        if app.api.isOwner() then app.editing = true

    $scope.getBoxClass = (app) ->
        if not app then return
        if app.mounted is true then return "mounted"
        else return "disabled"

    toggle = (app, property, method1, method2) ->
        if app[property]
            err = app.api[method1]()
            if err then console.log("#{method1} - #{err}")
            else app[property] = false
        else
            err = app.api[method2]()
            if err then console.log("#{method2} - #{err}")
            else app[property] = true

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
