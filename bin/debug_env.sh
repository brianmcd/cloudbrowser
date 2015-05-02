#!/bin/bash

# the following setting is good for debugging, disable monitoring logging and enable all output from virtual
# browser.
# export DEBUG=cloudbrowser:*,-cloudbrowser:master:proxy,-cloudbrowser:worker:socket,-cloudbrowser:sysmon,nodermi:error:*

if [[ "X$DEBUG" == "X" ]]; then
    export DEBUG=cloudbrowser:*,-cloudbrowser:master:proxy,-cloudbrowser:master:app,\
-cloudbrowser:worker:browser,-cloudbrowser:worker:browser:*,-cloudbrowser:worker:init,\
-cloudbrowser:worker:dom:*,-cloudbrowser:worker:socket,nodermi:error:*
fi

echo export DEBUG=$DEBUG
