CBLandingPage           = angular.module("CBLandingPage", [])
Util                    = require('util')

CBLandingPage.controller "UserCtrl", ($scope, $timeout) ->

    Months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

    $scope.safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase == '$apply' or phase == '$digest'
            if fn
                fn()
        else
            this.$apply(fn)

    formatDate = (date) ->
        if not date then return null
        month       = Months[date.getMonth()]
        day         = date.getDate()
        year        = date.getFullYear()
        hours       = date.getHours()
        timeSuffix  = if hours < 12 then 'am' else 'pm'
        hours       = hours % 12
        hours       = if hours then hours else 12
        minutes     = date.getMinutes()
        minutes     = if minutes > 10 then minutes else '0' + minutes
        time        = hours + ":" + minutes + " " + timeSuffix
        date        = day + " " + month + " " + year + " (" + time + ")"
        return date

    findInInstanceList = (id) ->
        instance = $.grep $scope.instanceList, (element, index) ->
           (element.id is id)
        return instance[0]

    addToInstanceList = (instanceID) ->
        if not findInInstanceList(instanceID)
            instance        = CloudBrowser.app.getInstanceInfo(instanceID)
            instance.date   = formatDate(instance.date)
            instance.owners = CloudBrowser.permissionManager.getInstanceOwners(instance.id)
            instance.collaborators = CloudBrowser.permissionManager.getInstanceReaderWriters(instance.id)
            CloudBrowser.app.registerListenerOnInstanceEvent instance.id, 'InstanceShared', () ->
                $scope.safeApply ->
                    instance.collaborators = CloudBrowser.permissionManager.getInstanceReaderWriters(instance.id)
                    instance.owners        = CloudBrowser.permissionManager.getInstanceOwners(instance.id)
            $scope.safeApply ->
                $scope.instanceList.push(instance)

    removeFromInstanceList = (id) ->
        $scope.safeApply ->
            oldLength = $scope.instanceList.length
            $scope.instanceList = $.grep $scope.instanceList, (element, index) ->
                return(element.id isnt id)
            if oldLength > $scope.instanceList.length
                removeFromSelected(id)

    toggleEnabledDisabled = (newValue, oldValue) ->

        checkPermission = (type, callback) ->
            outstanding = $scope.selected.length
            for instanceID in $scope.selected
                CloudBrowser.permissionManager.checkInstancePermissions type, instanceID,
                CloudBrowser.app.getCreator(), (hasPermission) ->
                    if not hasPermission
                        $scope.safeApply ->
                            callback(false)
                    else outstanding--

            process.nextTick () ->
                if not outstanding
                    $scope.safeApply ->
                        callback(true)
                else process.nextTick(arguments.callee)

        if newValue > 0
            $scope.isDisabled.open = false
            checkPermission {remove:true}, (canRemove) ->
                $scope.isDisabled.del           = not canRemove
            checkPermission {own:true}, (isOwner) ->
                $scope.isDisabled.share         = not isOwner
                $scope.isDisabled.rename        = not isOwner
        else
            $scope.isDisabled.open          = true
            $scope.isDisabled.del           = true
            $scope.isDisabled.rename        = true
            $scope.isDisabled.share         = true

    $scope.description  = CloudBrowser.app.getDescription()
    $scope.user         = CloudBrowser.app.getCreator()
    $scope.mountPoint   = CloudBrowser.app.getMountPoint()
    $scope.isDisabled   = {open:true, share:true, del:true, rename:true}
    $scope.instanceList = []
    $scope.selected     = []
    $scope.addingCollaborator = false
    $scope.confirmDelete      = false
    $scope.addingOwner  = false
    $scope.predicate    = 'date'
    $scope.reverse      = true
    $scope.filterType   = 'all'

    # Get the instances associated with the user
    CloudBrowser.app.getInstanceIDs $scope.user, (instanceIDs) ->
        for instanceID in instanceIDs
            addToInstanceList(instanceID)

    CloudBrowser.app.registerListenerOnEvent 'ItemAdded', (id) ->
        addToInstanceList(id)

    CloudBrowser.app.registerListenerOnEvent 'ItemRemoved', (id) ->
        removeFromInstanceList(id)

    $scope.$watch 'selected.length', (newValue, oldValue) ->
        toggleEnabledDisabled(newValue, oldValue)

    # Create a virtual instance
    $scope.createVB = () ->
        CloudBrowser.app.createInstance (err) ->
            if err
                $scope.safeApply () ->
                    $scope.error = err.message

    $scope.logout = () ->
        CloudBrowser.app.logout()

    # Change behaviour based on type of click
    $scope.open = () ->

        openNewTab = (instanceID) ->
            url = CloudBrowser.app.getUrl() + "/browsers/" + instanceID + "/index"
            win = window.open(url, '_blank')
            return

        for instanceID in $scope.selected
            openNewTab(instanceID)

    $scope.remove = () ->

        while $scope.selected.length > 0
            CloudBrowser.app.closeInstance $scope.selected[0], $scope.user, (err) ->
                if err
                    $scope.error = "You do not have the permission to perform this action"
                else if $scope.selected[0]? then removeFromInstanceList($scope.selected[0])
        $scope.confirmDelete = false
                        
    findAndRemove = (user, list) ->
        for i in [0..list.length-1]
            if list[i].email is user.email and
            list[i].ns is user.ns
                break
        if i < list.length
            list.splice(i, 1)

    $scope.openCollaborateForm = () ->

        $scope.addingCollaborator = !$scope.addingCollaborator

        if $scope.addingCollaborator

            $scope.addingOwner = false

            CloudBrowser.app.getUsers (users) ->
                if users?
                    for instanceID in $scope.selected
                        index = 0
                        while index < users.length
                            if CloudBrowser.permissionManager.isInstanceOwner(instanceID, users[index]) or
                            CloudBrowser.permissionManager.isInstanceReaderWriter(instanceID, users[index])
                                findAndRemove(users[index], users)
                            else index++
                
                $scope.safeApply ->
                    $scope.collaborators = users


    $scope.addCollaborator = () ->
        for instanceID in $scope.selected
            if CloudBrowser.permissionManager.isInstanceOwner(instanceID, $scope.user)
                CloudBrowser.permissionManager.grantInstancePermissions {readwrite:true}, $scope.selectedCollaborator, instanceID, () ->
                    $scope.safeApply ->
                        $scope.boxMessage = "The selected instances are now shared with " +
                        $scope.selectedCollaborator.email + " (" + $scope.selectedCollaborator.ns + ")"
                        $scope.addingCollaborator = false
            else
                $scope.error = "You do not have the permission to perform this action."

    $scope.openAddOwnerForm = () ->
        $scope.addingOwner = !$scope.addingOwner
        if $scope.addingOwner
            $scope.addingCollaborator = false
            CloudBrowser.app.getUsers (users) ->
                if users?
                    for instanceID in $scope.selected
                        index = 0
                        while index < users.length
                            if CloudBrowser.permissionManager.isInstanceOwner(instanceID, users[index])
                                findAndRemove(users[index], users)
                            else index++
                            
                $scope.safeApply ->
                    $scope.owners = users

    $scope.addOwner = () ->
        for instanceID in $scope.selected
            if CloudBrowser.permissionManager.isInstanceOwner(instanceID, $scope.user)
                CloudBrowser.permissionManager.grantInstancePermissions {own:true, remove:true, readwrite:true},
                $scope.selectedOwner, instanceID, () ->
                    $scope.safeApply ->
                        $scope.boxMessage = "The selected instances are now co-owned with " +
                        $scope.selectedOwner.email + " (" + $scope.selectedOwner.ns + ")"
                        $scope.addingOwner = false
            else
                $scope.error = "You do not have the permission to perform this action."

    addToSelected = (instanceID) ->
        if $scope.selected.indexOf(instanceID) is -1
            $scope.selected.push(instanceID)

    removeFromSelected = (instanceID) ->
        if $scope.selected.indexOf(instanceID) isnt -1
            $scope.selected.splice($scope.selected.indexOf(instanceID), 1)

    $scope.select = ($event, instanceID) ->
        checkbox = $event.target
        if checkbox.checked then addToSelected(instanceID) else removeFromSelected(instanceID)

    $scope.selectAll = ($event) ->
        checkbox = $event.target
        action = if checkbox.checked then addToSelected else removeFromSelected
        for instance in $scope.instanceList
            action(instance.id)

    $scope.getSelectedClass = (instanceID) ->
        if $scope.isSelected(instanceID)
            return 'highlight'
        else
            return ''

    $scope.isSelected = (instanceID) ->
        return ($scope.selected.indexOf(instanceID) >= 0)

    $scope.areAllSelected = () ->
        return $scope.selected.length is $scope.instanceList.length

    $scope.rename = () ->
        for instanceID in $scope.selected
            findInInstanceList(instanceID).editing = true

    $scope.clickRename = (instanceID) ->
        instance = findInInstanceList(instanceID)
        if isInstanceOwner(instance, $scope.user)
            instance.editing = true
        
CBLandingPage.filter "removeSlash", () ->
    return (input) ->
        mps = input.split('/')
        return mps[mps.length - 1]

CBLandingPage.filter "instanceFilter", () ->
    return (list, arg) =>
        filterType = arg.type
        user = arg.user
        modifiedList = []
        if filterType is 'owned'
            for instance in list
                if CloudBrowser.permissionManager.isInstanceOwner(instance.id, user)
                    modifiedList.push(instance)
        if filterType is 'notOwned'
            for instance in list
                if not CloudBrowser.permissionManager.isInstanceOwner(instance.id, user)
                    modifiedList.push(instance)
        if filterType is 'shared'
            for instance in list
                if CloudBrowser.permissionManager.getInstanceReaderWriters(instance.id).length or
                CloudBrowser.permissionManager.getInstanceOwners(instance.id).length > 1
                    modifiedList.push(instance)
        if filterType is 'notShared'
            for instance in list
                if CloudBrowser.permissionManager.getInstanceOwners(instance.id).length is 1 and
                not CloudBrowser.permissionManager.getInstanceReaderWriters(instance.id).length
                    modifiedList.push(instance)
        if filterType is 'all'
            modifiedList = list
        return modifiedList

