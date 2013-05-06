window.Utils =
    #dictionary of all the query key value pairs
    searchStringtoJSON : (searchString) ->
        if searchString[0] == "?"
            searchString = searchString.slice(1)
        search  = searchString.split("&")
        query   = {}
        for s in search
            pair = s.split("=")
            query[decodeURIComponent pair[0]] = decodeURIComponent pair[1]
        return query
