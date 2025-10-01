#!/bin/bash

cd /home/artin/Vshrd/macros
name=$1

if [[ $1 == "" ]]; then
				echo "No name given"
else
				touch temp
				nvim temp

				mv temp "$1"
				echo "$1" >> index
fi
