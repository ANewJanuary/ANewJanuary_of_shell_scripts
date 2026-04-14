#!/bin/bash

current_dow=$(date +%u)

days_until_monday=$(( (8 - current_dow) % 7 ))
if [ "$days_until_monday" -eq 0 ]; then
    days_until_monday=7
fi

template=""
days=("Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun")

for i in {0..6}; do
    offset=$(( days_until_monday + i ))
    day_of_month=$(date -d "+${offset} days" +%-d)
    line="### ${day_of_month} ${days[$i]}"
    if [ -n "$template" ]; then
        template="${template}
${line}"
    else
        template="${line}"
    fi
done

echo "$template" | wl-copy
