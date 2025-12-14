#!/bin/bash

cd /home/artin/Vshrd/shell-scripts;
rm 0000_db;
ls >> 0000_db;
chosen=$(grep -v "%" 0000_db | wofi -dpi 160 -dmenu -p "select script" -i -l 20);
echo "$chosen"
bash "$chosen"
