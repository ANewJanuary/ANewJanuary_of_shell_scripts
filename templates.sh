#!/bin/bash

TEMPLATE="$HOME/Vshrd/shell-scripts/templates/$(cd $HOME/Vshrd/shell-scripts/templates/ && ls | fuzzel --dmenu -l 10 -w 80)"

cp $TEMPLATE $PWD
