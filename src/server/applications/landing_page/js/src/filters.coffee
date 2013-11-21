filters = angular.module('CBLandingPage.filters', [])
filters.filter 'permissionFilter', () ->
    return (list, arg) ->
        {type, user} = arg
        modifiedList = []
        switch type
            when 'owned'
                for entity in list
                    if entity.api.isOwner(user)
                        modifiedList.push(entity)
            when 'notOwned'
                for entity in list
                    if not entity.api.isOwner(user)
                        modifiedList.push(entity)
            when 'shared'
                for entity in list
                    owner = if typeof(entity.api.getOwner) is "function" then 1 else 0
                    numCollaborators = owner +
                        entity.api.getReaderWriters().length +
                        ((entity.api.getOwners?().length) || 0) +
                        ((entity.api.getReaders?().length) || 0)
                    if numCollaborators > 1 then modifiedList.push(entity)
            when 'notShared'
                for entity in list
                    owner = if typeof(entity.api.getOwner) is "function" then 1 else 0
                    console.log("owner = #{owner}")
                    numCollaborators = owner +
                        entity.api.getReaderWriters().length +
                        ((entity.api.getOwners?().length)  || 0) +
                        ((entity.api.getReaders?().length) || 0)
                    if numCollaborators is 1 then modifiedList.push(entity)
            when 'all'
                modifiedList = list
        return modifiedList
