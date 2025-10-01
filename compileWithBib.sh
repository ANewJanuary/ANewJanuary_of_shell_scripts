#!/bin/sh
# A shell scripts that compiles latex with bib
echo file = "$1"

lualatex "$1".tex
bibtex "$1"
lualatex "$1".tex
lualatex "$1".tex
echo "DONE"
