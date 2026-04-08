#!/bin/bash

cd /home/artin/Vshrd/macros
read -rp "Name: " name

if [[ $name == "" ]]; then
				echo "No name given"
else
				touch temp
				hx temp

				mv temp "$name"
				echo "$name" >> index
fi
