# Note: the baseline for this was Zombie.js's Cakefile
fs            = require("fs")
path          = require("path")
{spawn, exec} = require("child_process")
stdout        = process.stdout

JS_FILES = [
    'client/socket.io.js'
    'server/XMLHttpRequest.js'
]

# Use executables installed with npm bundle.
process.env["PATH"] = "node_modules/.bin:#{process.env["PATH"]}"

# ANSI Terminal Colors.
bold  = "\033[0;1m"
red   = "\033[0;31m"
green = "\033[0;32m"
reset = "\033[0m"

# Log a message with a color.
log = (message, color, explanation) ->
  console.log color + message + reset + ' ' + (explanation or '')

# Handle error and kill the process.
onerror = (err)->
  if err
    process.stdout.write "#{red}#{err.stack}#{reset}\n"
    process.exit -1


## Setup ##
## TODO: run "cake build" in each example directory
task "setup", "Install development dependencies", ->
    log "Installing required npm packages (this could take some time)...", green
    npm = spawn "npm", ["install", "--dev"]
    npm.stdout.on 'data', (data) -> process.stdout.write data + reset
    npm.on 'error', (err) -> onerror err
    npm.on 'exit', ->
        log "Pulling required git submodules into deps/", green
        git = spawn "git", ['submodule', 'update', '--init']
        git.stdout.on 'data', (data) -> process.stdout.write data + reset
        git.on 'error', (err) -> onerror err
        git.on 'exit', ->
            deps = fs.readdirSync('deps')
            process.chdir('deps')
            deps.forEach (dep) ->
                log "Linking #{dep}", green
                exec "ln -s ../deps/#{dep} ../node_modules/", (err, stdout) ->
                    onerror err
                    process.chdir(dep)
                    log "Installing npm packages for #{dep}", green
                    depnpm = spawn "npm", ['install']
                    depnpm.stdout.on 'data', (data) -> process.stdout.write data + reset
                    depnpm.on 'error', (err) -> onerror err
                    process.chdir('..')

## Building ##
copyJS = (callback) ->
    log "Copying over raw js files ...", green
    count = 0
    for file in JS_FILES
        do (file) ->
            src = "#{path.join(__dirname, 'src', file)}"
            dst = "#{path.join(__dirname, 'lib', file)}"
            exec "mkdir -p #{path.dirname(dst)}", (err, stdout) ->
                if stdout != ""
                    log stdout, green
                onerror err
                exec "cp #{src} #{dst}", (err, stdout) ->
                    if stdout != ""
                        log stdout, green
                    onerror err
                    if ++count == JS_FILES.length
                        callback() if callback?
                
build = ->
    log "Compiling CoffeeScript to JavaScript ...", green
    exec "rm -rf lib/ build/ && coffee -c -l -b -o lib src", (err, stdout)->
        onerror err
        if stdout != ""
            log stdout, green
        copyJS()

task "build", "Compile CoffeeScript to JavaScript", -> build()

task "watch", "Continously compile CoffeeScript to JavaScript", ->
    exec "rm -rf lib", (err, stdout) ->
        copyJS ->
            cmd = spawn("coffee", ["-cwb", "-o", "lib", "src"])
            cmd.stdout.on "data", (data)-> process.stdout.write green + data + reset
            cmd.on "error", onerror

task "clean", "Remove temporary files and such", ->
    exec "rm -rf lib/", onerror

## Testing ##
runTests = (callback)->
  log "Running test suite ...", green
  exec "expresso -I lib/ test/test-base.coffee", (err, stdout, stderr)->
    process.stdout.write stdout
    process.binding("stdio").writeError stderr
    callback err if callback
task "test", "Run all tests", ->
  runTests (err)->
    process.stdout.on "drain", -> process.exit -1 if err
