#!/bin/bash
rm /home/artin/temp
touch /home/artin/temp
nofile="/home/artin/Vshrd/shell-scripts/no_fortunes.txt"
nos=$(cat $nofile)
max=$(cat $nofile | wc -l)
index=$(( RANDOM % max))
choice=$(shuf -n1 -e "nofortune" "fortune")
if [[ $choice == "nofortune" ]]; then
  # echo "${nos[$index]}" | fold -s -w $(($(tput cols) - 5 )) | cowsay -f small -n -C | lolcat -b -r
  random_element=$(printf "%s\n" "${nos[@]}" | shuf -n 1)
  echo "No. $random_element" | fold -s -w $(($(tput cols) - 5 )) | cowsay -f small -n -C | lolcat -b -r
fi
if [[ $choice == "fortune" ]]; then
  fortune >> /home/artin/temp
  cat /home/artin/temp | fold -s -w $(($(tput cols) - 5 )) | cowsay -f small -n -C | lolcat -b -r
fi

# fortune | fold -s -w $($(tput cols) - 4) | boxes -a hc -a vc -d ansi-double --no-color | fold -s -w $(tput cols) | lolcat -r -b && echo \n
# fortune | fold -s -w $(tput cols) | cowsay -f small | lolcat -r -b
