Async    = require('async')
NwGlobal = require('nwglobal')

app = angular.module('CBLandingPage.controllers.appInstance',
    [
        'CBLandingPage.models'
        'CBLandingPage.services'
    ]
)

appConfig = cloudbrowser.currentBrowser.getAppConfig()

app.controller 'AppInstanceCtrl', [
    '$scope'
    'cb-mail'
    'cb-format'
    'cb-appInstanceManager'
    ($scope, mail, format, appInstanceMgr) ->
        {appInstance} = $scope

        $scope.link = {}
        $scope.error = {}
        $scope.success = {}
        $scope.linkVisible  = false
        $scope.shareForm = {}
        $scope.shareFormOpen = false
        $scope.confirmDelete = {}

        $scope.showLink = (entity) ->
            if $scope.isLinkVisible() then $scope.closeLink()
            $scope.link.entity = entity
            $scope.linkVisible = true
            $scope.link.text = entity.api.getURL()

        $scope.isLinkVisible = () -> return $scope.linkVisible

        $scope.closeLink = () ->
            $scope.link.entity = null
            $scope.link.text   = null
            $scope.linkVisible = false

        $scope.tryToRemove = (entity, removalMethod) ->
            $scope.confirmDelete.entityName = entity.name
            $scope.confirmDelete.remove = () ->
                entity.api.close (err) ->
                    $scope.safeApply ->
                        if err then $scope.setError(err)
                        else $scope[removalMethod](entity)
                        $scope.confirmDelete.entityName = null

        $scope.isProcessing = () -> return appInstance.processing

        $scope.isBrowserTableVisible = () ->
            return appInstance.browserMgr.items.length and appInstance.showOptions

        $scope.isOptionsVisible = () ->
            return appInstance.showOptions

        $scope.hasCollaborators = () ->
            if not appInstance.collaborators then return false
            return appInstance.collaborators.length

        $scope.create = () ->
            appInstance.processing = true
            appInstance.api.createBrowser (err, browserConfig) ->
                if err then $scope.safeApply ->
                    $scope.setError(err)
                    appInstance.processing = false
                else $scope.addBrowser(browserConfig, appInstance)

        $scope.areCollaboratorsVisible = () ->
            return appInstance.showOptions and appInstance.collaborators.length

        $scope.toggleOptions = () ->
            appInstance.showOptions = not appInstance.showOptions

        appInstance.api.addEventListener 'rename', (name) ->
            $scope.safeApply -> appInstance.name = name

        appInstance.api.addEventListener 'share', (user) ->
            $scope.safeApply -> appInstance.collaborators.push(user)

        $scope.isShareFormOpen = () -> return $scope.shareFormOpen

        $scope.closeShareForm = () ->
            $scope.shareFormOpen = false
            # clear all the properties of the form
            $scope.shareForm[k] = null for k of $scope.shareForm

        # This method is shared by this controller and its child scope
        # i.e. the browser controller
        $scope.openShareForm = (entity) ->
            if $scope.isShareFormOpen() then $scope.closeShareForm()
            $scope.shareFormOpen = true
            $scope.shareForm.role = entity.roles[entity.defaultRoleIndex]
            $scope.shareForm.entity = entity

        grantPermissions = (user, form) ->
            {entity, role, collaborator} = form
            Async.series NwGlobal.Array(
                (next) ->
                    appInstance.processing = true
                    entity.api[role.grantMethod](user, next)
                    $scope.safeApply -> $scope.closeShareForm()
                (next) ->
                    mail.send
                        to   : user.getEmail()
                        url  : appConfig.getUrl()
                        from : $scope.user.email
                        callback   : next
                        sharedObj  : entity.name
                        mountPoint : appConfig.getMountPoint()
            ), (err) ->
                $scope.safeApply ->
                    if err then $scope.setError(err)
                    else $scope.success.message =
                        "#{entity.name} is shared with #{collaborator}."
                    appInstance.processing = false
                    appInstance.showOptions = true

        $scope.addCollaborator = () ->
            {collaborator} = $scope.shareForm
            lParIdx  = collaborator.indexOf("(")
            rParIdx  = collaborator.indexOf(")")
            EMAIL_RE = /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/
            
            # If the text box entry is a selection from the typeahead
            if lParIdx isnt -1 and rParIdx isnt -1
                emailID   = collaborator.substring(0, lParIdx-1)
                namespace = collaborator.substring(lParIdx + 1, rParIdx)
                user = new cloudbrowser.app.User(emailID, namespace)
                appConfig.isUserRegistered user, (err, exists) ->
                    $scope.safeApply ->
                        if err then $scope.setError(err)
                        else if exists
                            grantPermissions(user, $scope.shareForm)
                        else $scope.error.message = "Invalid Collaborator"
                        
            
            # If an email address has been entered directly
            # (not selected from the typeahead)
            # and the text entered is a valid email.
            else if lParIdx is -1 and rParIdx is -1 and
            EMAIL_RE.test(collaborator.toUpperCase())
                user = new cloudbrowser.app.User(collaborator, "google")
                appConfig.addNewUser user, () ->
                    grantPermissions(user, $scope.shareForm)

            else $scope.error.message = "Invalid Collaborator"
]
