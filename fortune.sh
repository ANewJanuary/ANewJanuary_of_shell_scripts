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
  printf '\e[48;5;0m' # Set background to black (code 0)              [~]
  random_element=$(printf "%s\n" "${nos[@]}" | shuf -n 1)
  echo -e "No. $random_element \n" | fold -s -w $(($(tput cols))) # | cowsay -f small -n -C | lolcat -b -r -g f5f5f5:eceff4
  printf '\e[0m'      # Reset colors
fi
if [[ $choice == "fortune" ]]; then
  fortune >> /home/artin/temp
  printf '\e[48;5;0m' # Set background to black (code 0)              [~]
  cat /home/artin/temp | fold -s -w $(($(tput cols) - 6 )) && echo -e "\n" # | cowsay -f small -n -C | lolcat -b -r -g f5f5f5:eceff4
  printf '\e[0m'      # Reset colors
fi

# fortune | fold -s -w $($(tput cols) - 4) | boxes -a hc -a vc -d ansi-double --no-color | fold -s -w $(tput cols) | lolcat -r -b && echo \n
# fortune | fold -s -w $(tput cols) | cowsay -f small | lolcat -r -b
