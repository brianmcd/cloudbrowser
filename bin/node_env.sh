#!/bin/bash
#set node parameter
export i_coffee=node_modules/coffee-script/bin/coffee

if [[ "X$CB_COFFEE_ARGS" == "X" ]]; then
    export CB_COFFEE_ARGS=" --nodejs --nouse-idle-notification "
fi

export i_exe="$i_coffee $CB_COFFEE_ARGS"

echo export CB_COFFEE_ARGS=$CB_COFFEE_ARGS