#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)

cd $i_scriptDir
cd js
echo "compile templates using handlebars"
handlebars *.tmpl > template.js