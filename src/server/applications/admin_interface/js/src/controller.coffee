Async    = require('async')
NwGlobal = require('nwglobal')

CBAdminInterface = angular.module("CBAdminInterface.controller", ['CBAdminInterface.models'])

CBAdminInterface.controller "AppCtrl", [
    '$scope'
    'cb-appManager'
    '$timeout'
    ($scope, appManager, $timeout) ->
        # Path to templates used in the view
        $scope.templates =
            switch           : "switch.html"
            appTable         : "app_table.html"
            appUsers         : "app_users.html"
            appBrowsers      : "app_browsers.html"
            appInstances     : "app_instances.html"
            appDescription   : "app_description.html"
            searchAndLogout  : "search_and_logout.html"
            selectedAppTable : "selected_app_table.html"

        for name, path of $scope.templates
            $scope.templates[name] = "#{__dirname}/partials/#{path}"

        $scope.safeApply = (fn) ->
            phase = this.$root.$$phase
            if phase is '$apply' or phase is '$digest'
                if fn then fn()
            else
                this.$apply(fn)
        
        # API objects
        curVB        = cloudbrowser.currentBrowser
        serverConfig = cloudbrowser.serverConfig

        # Model
        $scope.search = ""
        $scope.apps   = appManager.items
        $scope.switches = ['isPublic', 'isAuthEnabled', 'mounted']
        $scope.selectedApp = null
        $scope.user = curVB.getCreator()

        # TODO Must create directive instead
        $scope.setError = (err) ->
            $scope.error = err
            $timeout () ->
                $scope.error = null
            , 5000

        listsToRoles = {
            owner         : 'owner'
            owners        : 'owner'
            readers       : 'reader'
            readerwriters : 'readerwriter'
        }

        addToUserList = (app, user, list, id, role) ->
            u = app.userMgr.add(user)
            u[list].add({
                id   : id
                role : role
            })

        removeFromUserList = (app, user, list, id) ->
            u = app.userMgr.find(user)
            u[list].remove(id)

        addUser = (app, user) ->
            app.userMgr.add(user)
            app.api.getBrowsers user, (err, browserConfigs) ->
                for browserConfig in browserConfigs
                    u = app.browserMgr.find(browserConfig.getID())
                    browserConfig.getUserPrevilege((err,result)->
                        return setError(err) if err?
                        if result?
                            switch(result)
                                when 'own'
                                    $scope.safeApply -> u.owners.add({
                                        id   : browserConfig.getID()
                                        role : 'owner'
                                    })
                                when 'readwrite'
                                    $scope.safeApply -> u.readerwriters.add({
                                        id   : browserConfig.getID()
                                        role : 'readerwriter'
                                    })
                                when 'readonly'
                                    $scope.safeApply -> u.readers.add({
                                        id   : browserConfig.getID()
                                        role : 'reader'
                                    })
                        )


        addBrowsers = (app, browserConfigs, callback) ->
            if browserConfigs?
                for browserConfig in browserConfigs
                    addBrowser(app, browserConfig)

            if callback?
                callback null
            
            

        addBrowser = (app, browserConfig) ->
            browser = app.browserMgr.find(browserConfig.getID())
            if browser then return browser
            # Add browser if its not part of the list
            browser = app.browserMgr.add(browserConfig)
            # Add browser to its corresponding appInstance's list
            appInstance = app.appInstanceMgr.find(browser.appInstanceID)
            if not appInstance?
                #rare case, the appInstance has not been registered yet
                #TODO
                console.log "the appinstance is not registed for browser #{browserConfig.getID()}"
                return

            appInstance.browserIDMgr.add(browser.id)
            # Add browser to the corresponding users' list
            for listName, role of listsToRoles
                list = browser[listName]
                if list instanceof NwGlobal.Array then for user in list
                    addToUserList(app, user, 'browserIDMgr', browser.id, role)
            browser.api.addEventListener 'connect', (userInfo) ->
                $scope.safeApply ->
                    browser.connectedClientMgr.add(userInfo)
            browser.api.addEventListener 'disconnect', (email) ->
                $scope.safeApply ->
                    browser.connectedClientMgr.remove(email)
            browser.api.addEventListener 'share', (userInfo) ->
                {user, role} = userInfo
                $scope.safeApply ->
                    browser.updateUsers()
                    addToUserList(app, user, 'browserIDMgr', browser.id, role)
            # Setup event listeners for new user, rename
            
        removeBrowser = (app, browserID) ->
            browser = app.browserMgr.remove(browserID)
            # Remove browser from its corresponding appInstance's list
            if browser.appInstanceID
                appInstance = app.appInstanceMgr.find(browser.appInstanceID)
                appInstance.browserIDMgr.remove(browser.id)
            # Add browser to the corresponding users' list
            for listName, role of listsToRoles
                list = browser[listName]
                if list instanceof NwGlobal.Array then for user in list
                    removeFromUserList(app, user, 'browserIDMgr', browser.id)

        addAppInstances = (app, appInstanceConfigs, callback) ->
            for appInstanceConfig in appInstanceConfigs
                addAppInstance(app, appInstanceConfig)
            callback null
            

        addAppInstance = (app, appInstanceConfig) ->
            appInstance = app.appInstanceMgr.find(appInstanceConfig.getID())
            if appInstance then return appInstance
            # Add app instance if its not part of the list
            appInstance = app.appInstanceMgr.add(appInstanceConfig)
            # Get the users associated with the app instance
            for listName, role of listsToRoles
                # Add appInstance to user list
                list = appInstance[listName]
                if typeof list is "string"
                    addToUserList(app, list, 'appInstanceIDMgr', appInstance.id, role)
                else if list instanceof NwGlobal.Array then for user in list
                    addToUserList(app, user, 'appInstanceIDMgr', appInstance.id, role)

            appInstance.api.addEventListener 'share', (user) ->
                $scope.safeApply ->
                    appInstance.updateUsers()
                    addToUserList(app, user, 'appInstanceIDMgr', appInstance.id, 'readwriter')

            appInstance.api.addEventListener "addBrowser", (browserConfig) ->
                $scope.safeApply -> addBrowser(app, browserConfig)
            appInstance.api.addEventListener "removeBrowser", (id) ->
                $scope.safeApply -> removeBrowser(app, id)

            # get all browser from that appInstance
            appInstanceConfig.getAllBrowsers((err, browserConfigs)->
                if err?
                    console.log "error in getAllBrowsers #{err}"
                    return console.log err.stack
                addBrowsers(app, browserConfigs)
            )
            
            
        removeAppInstance = (app, appInstanceID) ->
            appInstance = app.appInstanceMgr.remove(appInstanceID)
            for listName, role of listsToRoles
                # Remove appInstance from user list
                list = appInstance[listName]
                if typeof list is "string"
                    removeFromUserList(app, list, 'appInstanceIDMgr', appInstance.id)
                else if list instanceof NwGlobal.Array then for user in list
                    removeFromUserList(app, user, 'appInstanceIDMgr', appInstance.id)

        setupEventListeners = (app) ->
            app.api.addEventListener "addAppInstance", (appInstanceConfig) ->
                $scope.safeApply -> addAppInstance(app, appInstanceConfig)
            app.api.addEventListener "removeAppInstance", (id) ->
                $scope.safeApply -> removeAppInstance(app, id)
            app.api.addEventListener "addUser", (user) ->
                $scope.safeApply -> addUser(app, user)
            app.api.addEventListener "removeUser", (user) ->
                $scope.safeApply -> app.userMgr.remove(user)

        addApp = (appConfig) ->
            app = appManager.find(appConfig.getMountPoint())
            # has already added
            if app then return app
            app = appManager.add(appConfig)
            setupEventListeners(app)
            # the browsers need to be retrieved after appInstances
            Async.auto(
                {
                    'appInstances' : (next)->
                        app.api.getAppInstances(next)
                    'addAppInstances' : ['appInstances', (next, results) ->
                        addAppInstances(app, results.appInstances, next)
                    ]
                    'users' : (next)->
                        app.api.getUsers(next)
                    'addUsers' : ['users', (next,results)->
                        users = results.users
                        for user in users
                            app.userMgr.add(user)
                        next(null)
                    ]
                }
                ,(err, results)->
                    console.log(err) if err
                    # pass an empty function to trigger apply
                    $scope.safeApply ->
                )



        # Application related events
        serverConfig.addEventListener "addApp", (appConfig) ->
            if appConfig.isOwner() then addApp(appConfig)

        serverConfig.addEventListener "removeApp", (mountPoint) ->
            appManager.remove(mountPoint)

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
            
        $scope.init = ()->
            # Loading all the apps at startup
            serverConfig.listApps ['perUser'], (err, appConfigs) ->
                if err then console.log err
                else
                    addApp(appConfig) for appConfig in appConfigs
                    # Select the first app initially
                    $scope.safeApply -> $scope.selectedApp = $scope.apps?[0]

        $scope.init()



        # Methods on the angular scope
        $scope.leftClick = (url) -> curVB.redirect(url)

        $scope.editDescription = () ->
            app = $scope.selectedApp
            if app.api.isOwner() then app.editing = true

        $scope.getAppClass = (app) ->
            if $scope.selectedApp is app then return 'selected'
            else return ''

        $scope.select = (app) ->
            $scope.selectedApp = app

        toggleMethods =
            mounted :
                on  : 'mount'
                off : 'disable'
            isPublic :
                on  : 'makePublic'
                off : 'makePrivate'
            isAuthEnabled :
                on  : 'enableAuthentication'
                off : 'disableAuthentication'

        $scope.toggle = (property) ->
            onMethod  = toggleMethods[property].on
            offMethod = toggleMethods[property].off

            if $scope.selectedApp[property]
                err = $scope.selectedApp.api[offMethod]()
                if err then console.log("#{offMethod} - #{err}")
                else $scope.selectedApp[property] = false
            else
                err = $scope.selectedApp.api[onMethod]()
                if err then console.log("#{onMethod} - #{err}")
                else $scope.selectedApp[property] = true

        $scope.sortBy = (predicate) ->
            $scope.predicate = predicate
            reverseProp = "#{predicate}-reverse"
            $scope[reverseProp] = not $scope[reverseProp]
            $scope.reverse = $scope[reverseProp]

        $scope.logout = () ->
            cloudbrowser.auth.logout()
]
