Async    = require('async')
NwGlobal = require('nwglobal')

app = angular.module('CBLandingPage.controllers.sharedState',
    [
        'CBLandingPage.models'
        'CBLandingPage.services'
    ]
)

appConfig = cloudbrowser.currentVirtualBrowser.getAppConfig()

app.controller 'SharedStateCtrl', [
    '$scope'
    'cb-mail'
    'cb-format'
    'cb-sharedStateManager'
    ($scope, mail, format, sharedStateManager) ->
        {sharedState} = $scope

        $scope.link = {}
        $scope.error = {}
        $scope.success = {}
        $scope.linkVisible  = false
        $scope.shareForm = {}
        $scope.shareFormOpen = false

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

        $scope.remove = () -> sharedStateManager.remove(sharedState)

        $scope.isProcessing = () -> return sharedState.processing

        $scope.isBrowserTableVisible = () ->
            return sharedState.browsers.length and sharedState.showOptions

        $scope.isOptionsVisible = () ->
            return sharedState.showOptions

        $scope.hasCollaborators = () ->
            if not sharedState.collaborators then return false
            return sharedState.collaborators.length

        $scope.addBrowser = () ->
            sharedState.processing = true
            sharedState.addBrowser()

        $scope.areCollaboratorsVisible = () ->
            return sharedState.showOptions and sharedState.collaborators.length

        $scope.toggleOptions = () ->
            sharedState.showOptions = not sharedState.showOptions

        # Event Handling
        sharedState.api.addEventListener 'addBrowser', (browserConfig) ->
            $scope.safeApply ->
                sharedState.addBrowserToList(browserConfig, $scope)
                sharedState.showOptions = true
                sharedState.processing = false

        sharedState.api.addEventListener 'removeBrowser', (id) ->
            $scope.safeApply ->
                sharedState.removeBrowserFromList(id)
                sharedState.processing = false

        sharedState.api.addEventListener 'share', () ->
            sharedState.api.getReaderWriters (err, readersWriters) ->
                $scope.safeApply ->
                    if err then $scope.setError(err)
                    else sharedState.readersWriters =
                        format.toJson(readersWriters)

        sharedState.api.addEventListener 'rename', (name) ->
            $scope.safeApply -> sharedState.name = name

        $scope.isShareFormOpen = () -> return $scope.shareFormOpen

        $scope.closeShareForm = () ->
            $scope.shareFormOpen = false
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
                    entity.api[role.grantMethod](user, next)
                (next) ->
                    $scope.closeShareForm()
                    $scope.success.message =
                        "#{entity.name} is shared with #{collaborator}."
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
                grantPermissions(user, $scope.shareForm)

            else $scope.error.message = "Invalid Collaborator"
]
