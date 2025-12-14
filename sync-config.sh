#!/bin/bash

# List of Dirs
kitty="/home/artin/.config/kitty/"
nvim="/home/artin/.config/nvim/"
waybar="/home/artin/.config/waybar/"
yazi="/home/artin/.config/yazi/"
zathura="/home/artin/.config/zathura/"
zk="/home/artin/.config/zk/"
zshrc="/home/artin/.config/.zshrc"

source="/home/artin/.config/"

# List of Sources
skitty="/home/artin/Vshrd/config/kitty/"
snvim="/home/artin/Vshrd/config/nvim/"
swaybar="/home/artin/Vshrd/config/waybar/"
syazi="/home/artin/Vshrd/config/yazi/"
szathura="/home/artin/Vshrd/config/zathura/"
szk="/home/artin/Vshrd/config/zk/"
szshrc="/home/artin/Vshrd/config/.zshrc"

dest="/home/artin/Vshrd/config/"

src=($kitty $nvim $waybar $yazi $zathura $zk $zshrc)
dst=($skitty $snvim $swaybar $syazi $szathura $szk $szshrc)

echo "$1"

if [[ "$1" == "push" ]]; then
  for ((i = 0; i < ${#src[@]}; i++)); do
    echo "${src[i]}"
    cp -f -r "${src[i]}" "$dest"
  done
elif [[ "$1" == "pull" ]]; then
  for ((i = 0; i < ${#src[@]}; i++)); do
    echo "${dst[i]}"
    cp -f -r "${dst[i]}" "$source"
  done
elif [[ $1 == "" ]]; then
  echo "No arguments provided."
  echo "say push to push your local to vshrd"
  echo "say pull to push your local to vshrd"
fi
