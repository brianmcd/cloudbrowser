# Note: the baseline for this was Zombie.js's Cakefile
fs            = require("fs")
path          = require("path")
{spawn, exec} = require("child_process")
stdout        = process.stdout

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

LINKS = []
LINKS.push
    src  : 'src/server/browser/XMLHttpRequest.js'
    dest : 'lib/server/browser/XMLHttpRequest.js'
LINKS.push
    src  : 'lib/shared/tagged_node_collection.js'
    dest : 'lib/client/tagged_node_collection.js'
LINKS.push
    src  : 'lib/shared/event_lists.js'
    dest : 'lib/client/event_lists.js'
LINKS.push
    src  : 'src/server/browser/event_patches.js'
    dest : 'lib/server/browser/event_patches.js'
LINKS.push
    src  : 'deps/knockout-node/build/output/knockout-node.debug.js'
    dest : 'lib/api/ko.js'

for file in fs.readdirSync('src/server/browser/knockout')
    LINKS.push
        src  : "src/server/browser/knockout/#{file}"
        dest : "lib/server/browser/knockout/#{file}"

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

## linkFiles  ##
linkFiles = (callback) ->
    count = 0
    fs.mkdirSync('lib/server/browser/knockout')
    for file in LINKS
        #log "Linking #{file.src} to #{file.dest}...", green
        src = path.resolve(__dirname, file.src)
        dest = path.resolve(__dirname, file.dest)
        exec "ln -s #{src} #{dest}", (err, stdout) ->
            onerror err
            if stdout != ""
                log stdout, green
            if (++count == LINKS.length) and callback?
                callback()

## Build ##
build = (callback) ->
    log "Compiling CoffeeScript to JavaScript...", green
    exec "rm -rf lib/ && coffee -c -l -b -o lib/ src/", (err, stdout) ->
        onerror err
        if stdout != ""
            log stdout, green
        linkFiles(callback)
task "build", "Compile CoffeeScript to JavaScript", -> build()

## Watch ##
task "watch", "Continously compile CoffeeScript to JavaScript", ->
    build ->
        cmd = spawn("coffee", ["-cwb", "-o", "lib", "src"])
        cmd.stdout.on "data", (data)-> process.stdout.write green + data + reset
        cmd.on "error", onerror

## Clean ##
task "clean", "Remove temporary files and such", ->
    exec "rm -rf lib/ && rm -rf lib-cov/", onerror

## Testing ##
runTests = (callback) ->
  log "Running test suite ...", green
  whiskey = spawn("node", ["run_tests.js"])
  whiskey.stdout.on "data", (data) -> process.stdout.write data
  whiskey.on 'error', onerror
  whiskey.on 'exit', () ->
      if callback
          callback()

task "test", "Run all tests", ->
  runTests()
