#!/bin/bash

cd /home/artin/Vshrd/macros

name=$(zenity --entry --text="Name: WARNING: text is taken from clipboard!")
text=$(wl-paste)

touch $name
wl-paste >> $name
