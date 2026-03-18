#!/bin/sh

cd /home/artin/Vshrd/macros
select=$(fzf -e)
cat $select | wl-copy
