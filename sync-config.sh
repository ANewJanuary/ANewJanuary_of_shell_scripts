#!/bin/bash

# List of config items to sync, parent directory
folders=(
  "kitty/"
  "swappy/"
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
      if cp -f -r "$local/$folder" "$sync/"; then
        echo "Copied $folder to $sync/$folder"
      else
        echo "Pushing $folder failed"
      fi
    done
fi

if [[ "$1" == "pull" ]]; then
    echo "Pull from $sync to $local"
    for folder in "${folders[@]}"
    do
      if cp -f -r "$sync/$folder" "$local/"; then
        echo "Copied $folder to $local/$folder"
      else
        echo "Pulling $folder failed"
      fi
    done
fi
