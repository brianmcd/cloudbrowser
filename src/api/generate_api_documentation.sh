curDir=`pwd`
if [[ $curDir != *src/api ]]
then
    echo "
Please run this script from inside the directory containing the API files.
"
    exit 1
fi

echo "
Removing the old documentation."
rm -rf out

echo "
Compiling the CoffeeScript files to JavaScript."
coffee -c *.coffee

echo "
Generating the Documentation using JSDOC."
jsdoc *.js

echo "
Cleaning up the JavaScript files."
find *.js -maxdepth 0 -name 'ko.js' -prune -o -exec rm '{}' ';'

echo "
Done."
echo "
Documentation can be found in the folder './out'"
