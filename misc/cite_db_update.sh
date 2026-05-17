#!/bin/bash

cd /home/artin/Documents/Vshrd/Sources;
rm 0000_db;
rm 0000_cite.bib;
ls >> 0000_db;
ln=$(cat 0000_db | wc -l);
cp 0000_backup.bib 0000_cite.bib;

for (( c=1; c<=$ln; c++ ))
do
    lin=$(sed -n -e "$c"p 0000_db)
    year=$(echo $lin | cut -d, -f1);
    title=$(echo $lin | cut -d, -f2);
    author=$(echo $lin | cut -d, -f3);
    string=$(echo $title | sed 's/ //g');
    #path=$(readlink -f $ln);
    echo "#Comment [[file:/home/artin/Documents/Vshrd/Sources/$lin][$lin]]" >> 0000_cite.bib;
    echo "@book{$string," >> 0000_cite.bib;
    echo "title=$title," >> 0000_cite.bib;
    echo "author=$author," >> 0000_cite.bib;
    echo "year=$year," >> 0000_cite.bib;
    echo "}" >> 0000_cite.bib;
done
