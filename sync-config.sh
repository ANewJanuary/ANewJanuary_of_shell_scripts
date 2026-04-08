#!/bin/bash

# List of config items to sync, parent directory
folders=(
  "kitty/"
  "helix/"
  "waybar/"
  "yazi/"
  "zathura/"
  "fish/"
  "hypr/"
  "zellij/"
  "fuzzel/"
  "ssh/"
  "emacs/"
)

# local locations
local="/home/artin/.config"
# sync folder
sync="/home/artin/Vshrd/config"


if [[ "$1" == "" ]]; then
  echo "No arguments. Use push or pull"
  echo "say push to push your local to vshrd"
  echo "say pull to pull from vshrd to local"
fi
if [[ "$1" == "push" ]]; then
    echo "Pushing $local to $sync"
    for folder in "${folders[@]}"
    do
      cp -f -r "$local/$folder" "$sync/"
      echo "Copied $folder to $sync/$folder"
    done
fi

if [[ "$1" == "pull" ]]; then
    echo "Pull from $sync to $local"
    for folder in "${folders[@]}"
    do
      cp -f -r "$sync/$folder" "$local/"
      echo "Copied $folder to $local/$folder"
    done
fi
# elif [[ "$1" == "pull" ]]; then
# fi

# if [[ "$1" == "push" ]]; then
#   for ((i = 0; i < ${#folders[@]}; i++)); do
#     echo "${src[i]}"
#     cp -f -r "${src[i]}" "$dest"
#   done
# elif [[ "$1" == "pull" ]]; then
#   for ((i = 0; i < ${#src[@]}; i++)); do
#     echo "${dst[i]}"
#     cp -f -r "${dst[i]}" "$source"
#   done
# elif [[ $1 == "" ]]; then
#   echo "No arguments provided."
#   echo "say push to push your local to vshrd"
#   echo "say pull to push your local to vshrd"
# fi
