#!/bin/bash

cd /home/artin/Documents/Vshrd/IB/ZK;
rm 0000_db;
rm 0000_lastsorted.csv;
ls >> 0000_db;
touch 0000_lastsorted.csv;
ln=$(cat 0000_db | wc -l);

for (( c=1; c<=$ln; c++ ))
do
    name=$(sed -n "$c"p 0000_db);
    title=$(cat /home/artin/Documents/Vshrd/IB/ZK/$name | grep "#+title:" | cut -d' ' -f2-);
    tag=$(cat /home/artin/Documents/Vshrd/IB/ZK/$name | grep "#+filetags:" | cut -d' ' -f2);
    echo "$tag, $title" >> 0000_lastsorted.csv;
done

echo "Done"
