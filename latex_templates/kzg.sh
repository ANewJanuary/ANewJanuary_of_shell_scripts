#!/bin/sh
# This is a shell script to copy and paste my default template for latex docs.

pathtofile="$LXS/kzg"

echo "Name of file: $1"
cp $pathtofile/* .
mv index.tex $1.tex
echo "DONE"
