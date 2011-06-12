# Note: the baseline for this was Zombie.js's Cakefile
fs            = require("fs")
path          = require("path")
{spawn, exec} = require("child_process")
stdout        = process.stdout

JS_FILES = ['client/socket.io.js']

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

# Setup development dependencies, not part of runtime dependencies.
task "setup", "Install development dependencies", ->
  fs.readFile "package.json", "utf8", (err, package)->
    log "Need runtime dependencies, installing into node_modules ...", green
    exec "npm install", onerror

    log "Need development dependencies, installing ...", green
    for name, version of JSON.parse(package).devDependencies
      log "Installing #{name} #{version}", green
      exec "npm install \"#{name}@#{version}\"", onerror

task "install", "Install Zombie in your local repository", ->
  build (err)->
    onerror err
    generateMan (err)->
      onerror err
      log "Installing Zombie ...", green
      exec "npm install", (err, stdout, stderr)->
        process.stdout.write stderr
        onerror err


## Building ##

copyJS = ->
    log "Copying over raw js files ...", green
    for file in JS_FILES
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

build = (callback)->
    log "Compiling CoffeeScript to JavaScript ...", green
    exec "rm -rf lib/ build/ && coffee -c -l -b -o lib src", (err, stdout)->
        onerror err
        if stdout != ""
            log stdout, green
        copyJS()
        log "Compiling native extension ...", green
        exec "node-waf configure build", callback
task "build", "Compile CoffeeScript to JavaScript", -> build onerror

task "watch", "Continously compile CoffeeScript to JavaScript", ->
    exec "rm -rf lib", (err, stdout) ->
        copyJS()
        cmd = spawn("coffee", ["-cw", "-o", "lib", "src"])
        cmd.stdout.on "data", (data)-> process.stdout.write green + data + reset
        cmd.on "error", onerror

clean = (callback)->
    exec "rm -rf lib/ build/", callback
task "clean", "Remove temporary files and such", -> clean onerror

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
