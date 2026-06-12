#!/bin/bash

arg="$1"

if [[ $arg == "" ]]; then
  echo "Which file should I invert?"
  exit 1
fi

echo $arg
svg-invert < "$arg" > temp.svg
mv temp.svg "$arg"
exit 0
