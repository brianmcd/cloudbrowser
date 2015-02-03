#!/bin/bash
if [[ "X$DEBUG" == "X" ]]; then
    export DEBUG=cloudbrowser:*,-cloudbrowser:master:proxy,-cloudbrowser:master:app,\
-cloudbrowser:worker:browser,-cloudbrowser:worker:browser:*,-cloudbrowser:worker:init,\
-cloudbrowser:worker:dom:*,-cloudbrowser:worker:socket
fi

echo export DEBUG=$DEBUG
