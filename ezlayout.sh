#!/bin/bash
current_split=$(hyprctl getoption dwindle:default_split_ratio -j | jq -r '.float')

if (( $(echo "$current_split == 1" | bc -l) )); then
    hyprctl keyword dwindle:default_split_ratio 0.5  # smaller
else
    hyprctl keyword dwindle:default_split_ratio 1   # Back to 50/50
fi
