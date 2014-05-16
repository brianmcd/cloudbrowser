os = require('os')
dns = require('dns')


exports.getLocalHostName = (callback)->
    try
        ipAddresses = []
        ifaces = os.networkInterfaces()
        for dev,iface of ifaces
            for alias in iface
                #console.log JSON.stringify(alias)
                if not alias.internal and alias.family is 'IPv4'
                    ipAddresses.push(alias.address)
        #console.log ipAddresses
        async.eachSeries(ipAddresses, (address, next)->
            try
                dns.reverse(address, (err, names)->
                    #console.log "#{address} #{names}"
                    return next(err) if err?
                    if names? and names.length>0
                        return callback(null, names[0])
                )
            catch e
                next e
        ,(err)->
            return callback(err,null) if err?
            callback(new Error("no names found for localhost"),null)
        )            
    catch e
        callback e, null

exports.getLocalHostIpAddress = (callback)->
    try
        ifaces = os.networkInterfaces()
        for dev,iface of ifaces
            for alias in iface
                #console.log JSON.stringify(alias)
                if not alias.internal and alias.family is 'IPv4'
                    return callback(null, alias.address)
        callback(new Error('cannot find IpAddress for localhost'), null)
    catch e
        callback e, null
