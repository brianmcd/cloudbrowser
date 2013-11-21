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
            if not appInstance.readerwriters then return false
            return appInstance.readerwriters.length

        $scope.create = () ->
            appInstance.processing = true
            appInstance.api.createBrowser (err, browserConfig) ->
                $scope.safeApply ->
                    if err
                        $scope.setError(err)
                        appInstance.processing = false
                    else
                        $scope.addBrowser(browserConfig, appInstance)

        $scope.areCollaboratorsVisible = () ->
            return appInstance.showOptions and appInstance.readerwriters.length

        $scope.toggleOptions = () ->
            appInstance.showOptions = not appInstance.showOptions

        appInstance.api.addEventListener 'rename', (name) ->
            $scope.safeApply -> appInstance.name = name

        appInstance.api.addEventListener 'share', (user) ->
            $scope.safeApply -> appInstance.readerwriters.push(user)

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

        grantPermissions = (form) ->
            {entity, role, collaborator} = form
            Async.series NwGlobal.Array(
                (next) ->
                    appInstance.processing = true
                    entity.api[role.grantMethod](collaborator, next)
                    $scope.safeApply -> $scope.closeShareForm()
                (next) ->
                    mail.send
                        to   : collaborator
                        url  : appConfig.getUrl()
                        from : $scope.user
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
            EMAIL_RE = /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/
            
            if EMAIL_RE.test(collaborator.toUpperCase())
                appConfig.isUserRegistered collaborator, (err, exists) ->
                    $scope.safeApply ->
                        return $scope.setError(err) if err
                        if exists
                            grantPermissions($scope.shareForm)
                        else appConfig.addNewUser collaborator, () ->
                            $scope.safeApply -> grantPermissions($scope.shareForm)
            else $scope.error.message = "Invalid Collaborator"
]
