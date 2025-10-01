#!/bin/bash
rm /home/artin/temp
touch /home/artin/temp
fortune >> /home/artin/temp
cat /home/artin/temp | cowsay -f tux -n -C | lolcat -b
