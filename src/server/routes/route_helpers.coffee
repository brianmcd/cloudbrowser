exports.redirect = (res, route) ->
    if not route then res.send(500)
    res.writeHead 302,
        'Location'      : route
        'Cache-Control' : "max-age=0, must-revalidate"
    res.end()

exports.removeTrailingSlash = (url) ->
    mountPoint = url.replace(/\/$/, "")
    mountPoint = if mountPoint is "" then "/" else mountPoint
    return mountPoint

exports.getMountPoint = (url) ->
    mountPoint = url.replace(/\/browsers\/.+\/.+$/, "")
    mountPoint = if mountPoint is "" then "/" else mountPoint
    return mountPoint
