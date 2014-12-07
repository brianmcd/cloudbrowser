#!/bin/bash
#set node parameter
export i_coffee=node_modules/coffee-script/bin/coffee

# disable default heapDump handler
# export NODE_HEAPDUMP_OPTIONS=nosignal

# to trace gc
# export CB_NODE_ARGS=" --nodejs '--nouse-idle-notification --trace-gc' "

if [[ "X$CB_NODE_ARGS" == "X" ]]; then
    export CB_NODE_ARGS="--nouse-idle-notification --expose-gc  --max_old_space_size=4096"
fi

echo export CB_NODE_ARGS=$CB_NODE_ARGS