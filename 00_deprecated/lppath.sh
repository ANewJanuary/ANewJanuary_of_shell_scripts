#!/bin/bash
cd ~/Vshrd/Learner-Portfolio
touch temp
select=$(find . -print | fzf)
ext=$(basename "$select")
name=$(echo "${ext%.*}")
echo -e "[[$name]]" > temp
echo "[$name]: $select" >> temp
cat temp | wl-copy
rm temp
