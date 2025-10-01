#!/bin/bash

cd /home/artin/Documents/Vshrd/IB/VT/KB/;
rm 0000_lastsorted.csv;
rm 0000_check;
rm 0000_check2;
cp /home/artin/Documents/Vshrd/IB/ZK/0000_lastsorted.csv .;
rm 0000_db;
rm 0000_notassigned;
ls >> 0000_db;

chosen=$(grep -v "%" 0000_db | rofi -dpi 160 -dmenu -p "select KnowledgeBase" -i -l 20);
tag=$(grep -v "%" 0000_tags | rofi -dpi 160 -dmenu -p "select tag" -i -l 20);

grep -oP '\]\[\K[^\]]*' "$chosen" > 0000_check;
grep "$tag" "0000_lastsorted.csv" | cut -d, -f2- > 0000_check2;

grep -F -v -f "0000_check" "0000_check2" > "0000_notassigned"

echo "Done!"
