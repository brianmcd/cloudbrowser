# A dynamic barrier that executes a callback when all outstanding tasks
# have finished.

###

# Example of how to use it

barrier = new Barrier () ->
    console.log("all timeouts have finished")

main = barrier.add()

for i in [1..10]
    (() ->
        outstandingtimeout = barrier.add()
        setTimeout () ->
            console.log("timeout #")
            outstandingtimeout.finish()
        , i * 100
    )()

main.finish()

###

class Barrier

    constructor : (@callback) ->
        @count = 0
        @reached = false

    # add a task
    add : () ->
        if @reached
            throw new Error("attempting to expand already reached barrier")
    
        @count++

        return {
        finish : () =>
            @count--
            if @count is 0
                @reached = true
                @callback()
        }

module.exports = Barrier
