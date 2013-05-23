CBLandingPage = angular.module("CBLandingPage", [])
Util = require('util')

CBLandingPage.controller "UserCtrl", ($scope, $timeout) ->

    Months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

    $scope.safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase == '$apply' or phase == '$digest'
            if fn then fn()
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

    addToInstanceList = (instance) ->
        if not findInInstanceList(instance.id)
            instance.dateCreated = formatDate(instance.dateCreated)
            instance.registerListenerOnEvent 'Shared', (err) ->
                if not err then $scope.safeApply ->
                    instance.owners = instance.getOwners()
                    instance.collaborators = instance.getReaderWriters()
                else console.log(err)
            instance.registerListenerOnEvent 'Renamed', (err, name) ->
                if not err then $scope.safeApply ->
                    instance.name = name
                else console.log(err)
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
                findInInstanceList(instanceID).checkPermissions type, (hasPermission) ->
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
    $scope.predicate    = 'dateCreated'
    $scope.reverse      = true
    $scope.filterType   = 'all'

    # Get the instances associated with the user
    CloudBrowser.app.getInstances (instances) ->
        for instance in instances
            addToInstanceList(instance)

    CloudBrowser.app.registerListenerOnEvent 'Added', (instance) ->
        addToInstanceList(instance)

    CloudBrowser.app.registerListenerOnEvent 'Removed', (id) ->
        removeFromInstanceList(id)

    $scope.$watch 'selected.length', (newValue, oldValue) ->
        toggleEnabledDisabled(newValue, oldValue)
        $scope.addingCollaborator = false
        $scope.addingOwner        = false

    # Create a virtual instance
    $scope.createVB = () ->
        CloudBrowser.app.createInstance (err) ->
            if err then $scope.safeApply () -> $scope.error = err.message

    $scope.logout = () ->
        CloudBrowser.auth.logout()

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
            findInInstanceList($scope.selected[0]).close (err) ->
                if err
                    $scope.error = "You do not have the permission to perform this action"
        $scope.confirmDelete = false
                        
    $scope.openCollaborateForm = () ->

        $scope.addingCollaborator = !$scope.addingCollaborator

        if $scope.addingCollaborator

            $scope.addingOwner = false

            CloudBrowser.app.getUsers (users) ->
                for instanceID in $scope.selected
                    instance = findInInstanceList(instanceID)
                    index = 0
                    while index < users.length
                        if instance.isOwner(users[index]) or
                        instance.isReaderWriter(users[index])
                            users.splice(index, 1)
                        else index++
                
                $scope.safeApply ->
                    $scope.collaborators = users

    $scope.addCollaborator = () ->
        for instanceID in $scope.selected
            instance = findInInstanceList(instanceID)
            if instance.isOwner($scope.user)
                instance.grantPermissions {readwrite:true}, $scope.selectedCollaborator, (err) ->
                    $scope.safeApply ->
                        if not err
                            $scope.boxMessage = "The selected instances are now shared with " +
                            $scope.selectedCollaborator.getEmail() + " (" + $scope.selectedCollaborator.getNameSpace() + ")"
                            $scope.addingCollaborator = false
                        else $scope.error = err
            else
                $scope.error = "You do not have the permission to perform this action."

    $scope.addGoogleCollaborator = () ->
        for instanceID in $scope.selected
            instance = findInInstanceList(instanceID)
            if instance.isOwner($scope.user)
                user    = new CloudBrowser.User($scope.selectedGoogleCollaborator, "google")
                subject = "CloudBrowser - #{$scope.user.getEmail()} shared an instance with you."
                msg     = "Hi #{user.getEmail()}<br>To view the instance, visit <a href='#{CloudBrowser.app.getUrl()}'>#{$scope.mountPoint}</a>"+
                          " and login with your google account."
                instance.grantPermissions {readwrite:true}, user, (err) ->
                    if not err
                        CloudBrowser.auth.sendEmail user.getEmail(), subject, msg, () ->
                            $scope.safeApply ->
                                $scope.boxMessage = "The selected instances are now shared with " +
                                $scope.selectedGoogleCollaborator + " (google)"
                                $scope.addingCollaborator = false
                    else $scope.safeApply -> $scope.error = err
            else
                $scope.error = "You do not have the permission to perform this action."

    $scope.openAddOwnerForm = () ->
        $scope.addingOwner = !$scope.addingOwner
        if $scope.addingOwner
            $scope.addingCollaborator = false
            CloudBrowser.app.getUsers (users) ->
                for instanceID in $scope.selected
                    instance = findInInstanceList(instanceID)
                    index = 0
                    while index < users.length
                        if instance.isOwner(users[index])
                            users.splice(index, 1)
                        else index++
                            
                $scope.safeApply ->
                    $scope.owners = users

    $scope.addOwner = () ->
        for instanceID in $scope.selected
            instance = findInInstanceList(instanceID)
            if instance.isOwner($scope.user)
                instance.grantPermissions {own:true, remove:true, readwrite:true},
                $scope.selectedOwner, (err) ->
                    $scope.safeApply ->
                        if not err
                            $scope.boxMessage = "The selected instances are now co-owned with " +
                            $scope.selectedOwner.getEmail() + " (" + $scope.selectedOwner.getNameSpace() + ")"
                            $scope.addingOwner = false
                        else $scope.error = err
            else
                $scope.error = "You do not have the permission to perform this action."

    $scope.addGoogleOwner = () ->
        for instanceID in $scope.selected
            instance = findInInstanceList(instanceID)
            if instance.isOwner($scope.user)
                user    = new CloudBrowser.User($scope.selectedGoogleOwner+"@gmail.com", "google")
                subject = "CloudBrowser - #{$scope.user.getEmail()} shared an instance with you."
                msg     = "Hi #{user.getEmail()}<br>To view the instance, visit <a href='#{CloudBrowser.app.getUrl()}'>#{$scope.mountPoint}</a>"
                instance.grantPermissions {own:true, remove:true, readwrite:true}, user, (err) ->
                    if not err
                        CloudBrowser.auth.sendEmail user.getEmail(), subject, msg, () ->
                            $scope.safeApply ->
                                $scope.boxMessage = "The selected instances are now co-owned with " +
                                $scope.selectedGoogleOwner + " (google)"
                                $scope.addingOwner = false
                    else $scope.safeApply -> $scope.error = err
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
        if instance.isOwner($scope.user)
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
                if instance.isOwner(user)
                    modifiedList.push(instance)
        if filterType is 'notOwned'
            for instance in list
                if not instance.isOwner(user)
                    modifiedList.push(instance)
        if filterType is 'shared'
            for instance in list
                if instance.getReaderWriters().length or
                instance.getOwners().length > 1
                    modifiedList.push(instance)
        if filterType is 'notShared'
            for instance in list
                if instance.getOwners().length is 1 and
                not instance.getReaderWriters().length
                    modifiedList.push(instance)
        if filterType is 'all'
            modifiedList = list
        return modifiedList

CBLandingPage.directive 'ngHasfocus', () ->
    return (scope, element, attrs) ->
        scope.$watch attrs.ngHasfocus, (nVal, oVal) ->
            if (nVal)
                element[0].focus()
        element.bind 'blur', () ->
            scope.$apply(attrs.ngHasfocus + " = false";scope.instance.rename(scope.instance.name))
        element.bind 'keydown', (e) ->
            if e.which is 13
                scope.$apply(attrs.ngHasfocus + " = false";scope.instance.rename(scope.instance.name))
