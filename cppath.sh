#!/bin/bash
cd ~
echo -n "~/$(fzf -e)" | wl-copy
