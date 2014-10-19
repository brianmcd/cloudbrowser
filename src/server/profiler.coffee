heapdump = require('heapdump')
debug = require('debug')
moment = require('moment')

logger = debug("cloudbrowser:profiler")

gcfunc = ()->
    logger("gc is not defined, plese specify --expose-gc flag")

if typeof gc is 'function'
    gcfunc = gc

#pid = process.pid

formatTime = (time)->
    moment(time).format('YYYYMMDDHHmmssSSS')

# kill -3 to dump heap
process.on('SIGQUIT', ()->
    # gc before dump heap
    gcfunc()
    fileName = "heapdump_#{formatTime(Date.now())}.heapsnapshot"
    # at least in 0.2.10, callback function in this api does not work
    heapdump.writeSnapshot(fileName)
    logger("dumping heap to #{fileName}")
)