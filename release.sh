#!/bin/sh
#
rm -rf release
mkdir -p release
cp -R -u csss haxelib.json release
chmod -R 777 release
cd release
zip -r release.zip ./ && mv release.zip ../
cd ..
