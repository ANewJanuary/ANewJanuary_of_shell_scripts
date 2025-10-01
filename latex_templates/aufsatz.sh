#!/bin/sh

# This is a shell script to copy and paste my short story template for latex docs.

pathtofile="$LXS/Aufsatz"

echo "Name of file: $1"
cp $pathtofile/* .
mv index.tex $1.tex
echo "DONE"
