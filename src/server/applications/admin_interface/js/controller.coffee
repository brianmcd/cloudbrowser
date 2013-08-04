CBAdmin = angular.module("CBAdmin", [])

CBAdmin.controller "AppCtrl", ($scope) ->

    $scope.apps = []

    class App
        constructor : (appConfig) ->
            @description = appConfig.getDescription()
            @mountPoint  = appConfig.getMountPoint()
            @url         = appConfig.getUrl()
            @instantiationStrategy =
                @camelCaseToWords(appConfig.getInstantiationStrategy())
            @browserLimit  = appConfig.getBrowserLimit()
            @isAuthEnabled = appConfig.isAuthConfigured()
            @isPublic      = appConfig.isAppPublic()
            @mounted       = appConfig.isMounted()
            @api = appConfig
            appConfig.getUsers (users) =>
                $scope.safeApply => @users = users
            appConfig.getVirtualBrowsers (virtualBrowsers) =>
                $scope.safeApply => @virtualBrowsers = virtualBrowsers

            @setupEventListeners()

            App.add(this)

        camelCaseToWords : (camelCaseString) ->
            camelCaseString
                # Insert a space before all caps
                .replace(/([A-Z])/g, ' $1')
                # Convert the first character to uppercase
                .replace(/^./, (str) -> str.toUpperCase())

        @find : (mountPoint) ->
            app = $.grep $scope.apps, (element, index) ->
                element.mountPoint is mountPoint
            return app[0]

        @add : (app) ->
            $scope.safeApply ->
                $scope.apps.push(app)

        @remove : (mountPoint) ->
            $scope.safeApply ->
                $scope.apps = $.grep $scope.apps, (element, index) ->
                    return element.mountPoint isnt mountPoint

        setupEventListeners : () ->
            @api.addEventListener "added", (vb) =>
                $scope.safeApply =>
                    @virtualBrowsers.push(vb)
            @api.addEventListener "removed" , (vbID) =>
                $scope.safeApply =>
                    @virtualBrowsers =
                        $.grep @virtualBrowsers, (element, index) ->
                            return element.id isnt vbID



    $scope.safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase == '$apply' or phase == '$digest'
            if fn then fn()
        else
            this.$apply(fn)

    curInstance  = cloudbrowser.currentVirtualBrowser
    serverConfig = cloudbrowser.serverConfig

    $scope.selectedApp = null
    $scope.areverse = $scope.ureverse = $scope.mreverse = $scope.ireverse =
        $scope.preverse = false

    serverConfig.listApps
        filters :
            perUser : true
        callback : (appConfigs) ->
            for appConfig in appConfigs
                new App(appConfig)
            if $scope.apps.length
                $scope.safeApply ->
                    $scope.selectedApp = $scope.apps[0]

    $scope.user = curInstance.getCreator()

    $scope.leftClick = (url) ->
        curInstance.redirect(url)

    $scope.editDescription = (mountPoint) ->
        app = App.find(mountPoint)
        ###
        app.isOwner $scope.user, (isOwner) ->
            if isOwner then $scope.safeApply -> app.editing = true
        ###
        app.editing = true

    $scope.getBoxClass = (mountPoint) ->
        if not mountPoint then return
        if App.find(mountPoint).mounted is true
            return "mounted"
        else return "disabled"

    $scope.toggleMountDisable = (mountPoint) ->
        app = App.find(mountPoint)
        if app.mounted
            if not app.api.disable()
                app.mounted = false
        else
            if not app.api.mount()
                app.mounted = true

    $scope.togglePrivacy = (mountPoint) ->
        app = App.find(mountPoint)
        if app.isPublic
            # If there's no error
            if not app.api.makePrivate()
                app.isPublic = false
        else
            if not app.api.makePublic()
                app.isPublic = true

    $scope.toggleAuthentication = (mountPoint) ->
        app = App.find(mountPoint)
        if app.isAuthEnabled
            if not app.api.disableAuthentication()
                app.isAuthEnabled = false
        else
            if not app.api.enableAuthentication()
                app.isAuthEnabled = true

    $scope.selectApp = (mountPoint) ->
        $scope.selectedApp = App.find(mountPoint)
    
    $scope.getAppClass = (app) ->
        if $scope.selectedApp is app then return "selected"
        else return ""

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
