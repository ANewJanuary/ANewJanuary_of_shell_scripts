#!/bin/bash
rm /home/artin/temp
touch /home/artin/temp
fortune >> /home/artin/temp
cat /home/artin/temp | fold -s -w $(($(tput cols) - 5 )) | cowsay -f small -n -C | lolcat -b -r

# fortune | fold -s -w $($(tput cols) - 4) | boxes -a hc -a vc -d ansi-double --no-color | fold -s -w $(tput cols) | lolcat -r -b && echo \n
# fortune | fold -s -w $(tput cols) | cowsay -f small | lolcat -r -b
