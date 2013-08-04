# TODO - Refactor the whole code
cb = {}
cb.currentVirtualBrowser = cloudbrowser.currentVirtualBrowser
cb.appConfig             = cb.currentVirtualBrowser.getAppConfig()
cb.util                  = cloudbrowser.util
cb.auth                  = cloudbrowser.auth

CBLandingPage = angular.module("CBLandingPage", [])
CBLandingPage.controller "UserCtrl", ($scope, $timeout) ->

    $scope.user           = cb.currentVirtualBrowser.getCreator()
    $scope.description    = cb.appConfig.getDescription()
    $scope.mountPoint     = cb.appConfig.getMountPoint()
    $scope.isDisabled     = {open:true, share:true, del:true, rename:true}
    $scope.virtualBrowserList = []
    $scope.selected       = []
    $scope.addingReaderWriter = false
    $scope.confirmDelete      = false
    $scope.addingOwner    = false
    $scope.predicate      = 'dateCreated'
    $scope.reverse        = true
    $scope.filterType     = 'all'

    # Calls $apply only when not already in a digest cycle
    $scope.safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase == '$apply' or phase == '$digest'
            if fn then fn()
        else
            this.$apply(fn)

    months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    utils =
        formatDate : (date) ->
            if not date then return null
            month       = months[date.getMonth()]
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

    # Operates on $scope.virtualBrowserList -
    # The list of browsers corresponding to the current user.
    vbMgr =
        find : (id) ->
            vb = $.grep $scope.virtualBrowserList, (element, index) ->
               (element.id is id)
            return vb[0]

        add : (vbAPI) ->
            if not @find(vbAPI.id)
                # Creating the vb object
                vb =
                    api    : vbAPI
                    id     : vbAPI.id
                    name   : vbAPI.getName()
                    dateCreated  : utils.formatDate(vbAPI.dateCreated)

                vb.api.getOwners (owners) ->
                    vb.owners = owners

                vb.api.getReaderWriters (readerWriters) ->
                    vb.collaborators = readerWriters

                # Adding the event listeners
                vb.api.addEventListener 'shared', (err) ->
                    # TODO : Better error handling?
                    console.log(err) if err
                    vb.api.getOwners (owners) ->
                        $scope.safeApply -> vb.owners = owners
                    vb.api.getReaderWriters (readersWriters) ->
                        $scope.safeApply -> vb.collaborators = readersWriters

                vb.api.addEventListener 'renamed', (err, name) ->
                    console.log(err) if err
                    $scope.safeApply -> vb.name = name

                # Adding vb object to list
                $scope.safeApply ->
                    $scope.virtualBrowserList.push(vb)

        remove : (id) ->
            $scope.safeApply ->
                oldLength = $scope.virtualBrowserList.length

                $scope.virtualBrowserList = $.grep $scope.virtualBrowserList, (element, index) ->
                    return(element.id isnt id)
                
                # TODO : Why is this required?
                if oldLength > $scope.virtualBrowserList.length
                    selected.remove(id)

    # Operates on $scope.selected - The browsers selected by the user.
    selected =
        add : (id) ->
            if $scope.selected.indexOf(id) is -1
                $scope.selected.push(id)

        remove : (id) ->
            if $scope.selected.indexOf(id) isnt -1
                $scope.selected.splice($scope.selected.indexOf(id), 1)

    # Checks if user has the permission to perform the action of "type"
    # on all the selected browsers
    checkPermission = (type, callback) ->
        outstanding = $scope.selected.length
        callbackNotCalled = true

        # Looping through all selected browsers
        for id in $scope.selected
            vbMgr.find(id).api.checkPermissions type, (hasPermission) ->
                # If user doesn't have permission for even one browser
                # immediately return false
                if not hasPermission
                    $scope.safeApply -> callback(false)
                    callbackNotCalled = false
                    outstanding = 0
                else if outstanding then outstanding--

        # Find when all selected browsers have been iterated over
        process.nextTick () ->
            # If user has permissions to perform the requested action
            # for all selected browsers return true
            if not outstanding
                if callbackNotCalled
                    $scope.safeApply -> callback(true)
            else process.nextTick(arguments.callee)

    # Toggle the action buttons
    toggleEnabledDisabled = (newValue, oldValue) ->
        # If at least one browser has been selected
        # i.e the checkbox next to at least one browser
        # is checked
        if newValue > 0
            # Anybody can open
            $scope.isDisabled.open = false
            # Check if the remove button should be enabled
            checkPermission {remove:true}, (canRemove) ->
                $scope.isDisabled.del           = not canRemove
            # Check if the share and rename button should be enabled
            checkPermission {own:true}, (isOwner) ->
                $scope.isDisabled.share         = not isOwner
                $scope.isDisabled.rename        = not isOwner
        else
            # disable all buttons
            $scope.isDisabled.open   = true
            $scope.isDisabled.del    = true
            $scope.isDisabled.rename = true
            $scope.isDisabled.share  = true

    cb.appConfig.getVirtualBrowsers (virtualBrowsers) ->
        for vbAPI in virtualBrowsers
            vbMgr.add(vbAPI)

    cb.appConfig.addEventListener 'added', (vbAPI) ->
        vbMgr.add(vbAPI)

    cb.appConfig.addEventListener 'removed', (id) ->
        vbMgr.remove(id)

    $scope.$watch 'selected.length', (newValue, oldValue) ->
        toggleEnabledDisabled(newValue, oldValue)
        $scope.addingReaderWriter = false
        $scope.addingOwner        = false

    $scope.createVB = () ->
        cb.appConfig.createVirtualBrowser (err) ->
            if err then $scope.safeApply () -> $scope.error = err.message

    $scope.logout = () -> cb.auth.logout()

    $scope.open = () ->
        openNewTab = (id) ->
            url = cb.appConfig.getUrl() + "/browsers/" + id + "/index"
            win = window.open(url, '_blank')
            return

        for id in $scope.selected
            openNewTab(id)

    $scope.remove = () ->
        while $scope.selected.length > 0
            vbMgr.find($scope.selected[0]).api.close (err) ->
                if err
                    $scope.error = "You do not have the permission to perform this action"
        $scope.confirmDelete = false
                        
    sendMail = (email) ->
        subject = "CloudBrowser - #{$scope.user.getEmail()} shared an vb with you."
        msg = "Hi #{email}<br>To view the vb, visit <a href='#{cb.appConfig.getUrl()}'>" +
              "#{$scope.mountPoint}</a> and login to your existing account or use your google ID to login if" +
              " you do not have an account already."
        cb.util.sendEmail email, subject, msg, () ->
        
    grantPerm = (user, perm, callback) ->
        # Looping through the selected browsers
        for id in $scope.selected
            vb = vbMgr.find(id)
            do (vb) ->
                # Checking whether the current user has the
                # permission to share this browser with others
                vb.api.isOwner $scope.user, (isOwner) ->
                    if isOwner
                        # Grant permissions to selected user
                        vb.api.grantPermissions perm, user, (err) ->
                            if not err
                                sendMail(user.getEmail())
                                callback(user)
                            else $scope.safeApply -> $scope.error = err
                    else $scope.safeApply ->
                        $scope.error = "You do not have the permission to perform this action."

    addCollaborator = (selectedUser, perm, callback) ->
        lParIdx = selectedUser.indexOf("(")
        rParIdx = selectedUser.indexOf(")")

        # If the text box entry is a selection from the typeahead
        if lParIdx isnt -1 and rParIdx isnt -1
            # Parse the string to get the email and namespace
            emailID   = selectedUser.substring(0, lParIdx-1)
            namespace = selectedUser.substring(lParIdx+1, rParIdx)
            # Construct a cloudbrowser user
            user      = new cloudbrowser.app.User(emailID, namespace)
            # Check if the cloudbrowser is in the db for this app
            cb.appConfig.isUserRegistered user, (exists) ->
                # If so, add the user as a collaborator corresponding to the permissions
                if exists then grantPerm(user, perm, callback)
                # String in the textbox is not in the correct format
                else $scope.safeApply -> $scope.error = "Invalid Collaborator Selected"

        # If an email address has been entered directly (not selected from the typeahead)
        # and the text entered is a valid email.
        else if lParIdx is -1 and rParIdx is -1 and
        /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test(selectedUser.toUpperCase())
            user = new cloudbrowser.app.User(selectedUser, "google")
            # Add the user as a collaborator corresponding to the permissions
            grantPerm(user, perm, callback)

        # String in the textbox is not in the correct format
        else $scope.error = "Invalid Collaborator Selected"

    $scope.openAddReaderWriterForm = () ->
        # Toggle the form
        $scope.addingReaderWriter = !$scope.addingReaderWriter
        # If add readerwriter form is open, close the add owner form
        if $scope.addingReaderWriter then $scope.addingOwner = false

    $scope.addReaderWriter = () ->
        addCollaborator $scope.selectedReaderWriter, {readwrite:true}, (user) ->
            $scope.safeApply ->
                # Display success message
                $scope.boxMessage = "The selected virtual browsers are now shared with " +
                user.getEmail() + " (" + user.getNameSpace() + ")"
                # Close the form
                $scope.addingReaderWriter = false
                # Clear the text box
                $scope.selectedReaderWriter = null

    $scope.openAddOwnerForm = () ->
        # Toggle the form
        $scope.addingOwner = !$scope.addingOwner
        # If add owner form is open, close the add readerwriter form
        if $scope.addingOwner then $scope.addingReaderWriter = false

    $scope.addOwner = () ->
        addCollaborator $scope.selectedOwner, {own:true, remove:true, readwrite:true}, (user) ->
            $scope.safeApply ->
                # Display success message
                $scope.boxMessage = "The selected virtualBrowsers are now shared with " +
                user.getEmail() + " (" + user.getNameSpace() + ")"
                # Close the form
                $scope.addingOwner   = false
                # Clear the text box
                $scope.selectedOwner = null

    $scope.select = ($event, id) ->
        checkbox = $event.target
        if checkbox.checked then selected.add(id) else selected.remove(id)

    $scope.selectAll = ($event) ->
        checkbox = $event.target
        action = if checkbox.checked then selected.add else selected.remove
        for vb in $scope.virtualBrowserList
            action(vb.id)

    $scope.getSelectedClass = (id) ->
        if $scope.isSelected(id) then return 'highlight'
        else return ''

    $scope.isSelected = (id) ->
        return ($scope.selected.indexOf(id) >= 0)

    $scope.areAllSelected = () ->
        return $scope.selected.length is $scope.virtualBrowserList.length

    $scope.rename = () ->
        for id in $scope.selected
            vbMgr.find(id).editing = true

    $scope.clickRename = (id) ->
        vb = vbMgr.find(id)
        vb.api.isOwner $scope.user, (isOwner) ->
            if isOwner then $scope.safeApply -> vb.editing = true
        
CBLandingPage.filter "removeSlash", () ->
    return (input) ->
        mps = input.split('/')
        return mps[mps.length - 1]

CBLandingPage.filter "virtualBrowserFilter", () ->
    return (list, arg) =>
        filterType = arg.type
        user = arg.user
        modifiedList = []
        if filterType is 'owned'
            for vb in list
                do (vb) ->
                    vb.api.isOwner user, (isOwner) ->
                        if isOwner then modifiedList.push(vb)
        if filterType is 'notOwned'
            for vb in list
                do (vb) ->
                    vb.api.isOwner user, (isOwner) ->
                        if not isOwner then modifiedList.push(vb)
        if filterType is 'shared'
            for vb in list
                do (vb) ->
                    vb.api.getNumReaderWriters (numReaderWriters) ->
                        if numReaderWriters then modifiedList.push(vb)
                        else vb.api.getNumOwners (numOwners) ->
                            if numOwners > 1 then modifiedList.push(vb)
        if filterType is 'notShared'
            for vb in list
                do (vb) ->
                    vb.api.getNumOwners (numOwners) ->
                        if numOwners is 1
                            vb.api.getNumReaderWriters (numReaderWriters) ->
                                if not numReaderWriters
                                    modifiedList.push(vb)
        if filterType is 'all'
            modifiedList = list
        return modifiedList

CBLandingPage.directive 'ngHasfocus', () ->
    return (scope, element, attrs) ->
        scope.$watch attrs.ngHasfocus, (nVal, oVal) ->
            if (nVal)
                element[0].focus()
        element.bind 'blur', () ->
            scope.$apply(attrs.ngHasfocus + " = false";scope.vb.api.rename(scope.vb.name))
        element.bind 'keydown', (e) ->
            if e.which is 13
                scope.$apply(attrs.ngHasfocus + " = false";scope.vb.api.rename(scope.vb.name))

CBLandingPage.directive 'typeahead', () ->
    directive =
        restrict : 'A',
        link : (scope, element, attrs) ->
            args =
                source : (query, process) ->
                    data = []
                    cb.appConfig.getUsers (users) ->
                        for id in scope.selected
                            vb = $.grep scope.virtualBrowserList, (element, index) ->
                               (element.id is id)
                            vb = vb[0]; index = 0
                            if attrs.typeahead is "selectedReaderWriter"
                                while index < users.length
                                    user = users[index]
                                    do (user) ->
                                        vb.api.isOwner user, (isOwner) ->
                                            if isOwner then scope.safeApply -> users.splice(index, 1)
                                            else vb.api.isReaderWriter user, (isReaderWriter) ->
                                                scope.safeApply ->
                                                    if isReaderWriter then users.splice(index, 1)
                                                    else index++
                            else if attrs.typeahead is "selectedOwner"
                                while index < users.length
                                    user = users[index]
                                    do (user) ->
                                        vb.api.isOwner user, (isOwner) ->
                                            scope.safeApply ->
                                                if isOwner then users.splice(index, 1)
                                                else index++
                        for collaborator in users
                            data.push(collaborator.getEmail() + ' (' + collaborator.getNameSpace() + ')')
                        process(data)
                updater : (item) ->
                    scope.$apply(attrs.typeahead + " = '#{item}'")
                    return item
            $(element).typeahead(args)
