# Note: the baseline for this was Zombie.js's Cakefile
fs            = require("fs")
path          = require("path")
{spawn, exec} = require("child_process")
stdout        = process.stdout

LINKS = [
        src : 'src/server/browser/dom/XMLHttpRequest.js'
        dest : 'lib/server/browser/dom/XMLHttpRequest.js'
    ,
        src : 'lib/shared/tagged_node_collection.js'
        dest : 'lib/client/tagged_node_collection.js'
    ,
        src : 'lib/shared/event_lists.js'
        dest : 'lib/client/event_lists.js'
    ,
        src : 'src/server/browser/dom/event_patches.js'
        dest : 'lib/server/browser/dom/event_patches.js'
    ,
        src : 'deps/knockout-node/build/output/knockout-node.debug.js'
        dest : 'lib/api/ko.js'
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
            count = 0
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
                    if ++count == deps.length
                        process.chdir('..')
                        runTests()

## Building ##
linkFiles = (callback) ->
    count = 0
    for file in LINKS
        log "Linking #{file.src} to #{file.dest}...", green
        src = path.resolve(__dirname, file.src)
        dest = path.resolve(__dirname, file.dest)
        exec "ln -s #{src} #{dest}", (err, stdout) ->
            onerror err
            if stdout != ""
                log stdout, green
            if ++count == LINKS.length
                if callback
                    callback()

build = (callback) ->
    log "Compiling CoffeeScript to JavaScript...", green
    exec "rm -rf lib/ && coffee -c -l -b -o lib/ src/", (err, stdout) ->
        onerror err
        if stdout != ""
            log stdout, green
        log "Building tests...", green
        exec "rm -rf test/ && coffee -c -l -b -o test/ test-src/", (err, stdout) ->
            onerror err
            if stdout != ""
                log stdout, green
            linkFiles(callback)
task "build", "Compile CoffeeScript to JavaScript", -> build()

task "watch", "Continously compile CoffeeScript to JavaScript", ->
    build ->
        cmd = spawn("coffee", ["-cwb", "-o", "lib", "src"])
        cmd.stdout.on "data", (data)-> process.stdout.write green + data + reset
        cmd.on "error", onerror

        testcmd = spawn("coffee", ["-cwb", "-o", "test", "test-src"])
        testcmd.stdout.on "data", (data)-> process.stdout.write green + data + reset
        testcmd.on "error", onerror

task "clean", "Remove temporary files and such", ->
    exec "rm -rf lib/ && rm -rf test/", onerror

## Testing ##
runTests = (callback) ->
  log "Running test suite ...", green
  nodeunit = spawn("node", ["run_tests.js"])
  nodeunit.stdout.on "data", (data) -> process.stdout.write data
  nodeunit.on 'error', onerror
  nodeunit.on 'exit', () ->
      if callback
          callback()
task "test", "Run all tests", ->
  runTests()
