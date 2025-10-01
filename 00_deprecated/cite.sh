#!/bin/bash

# Read the file containing citations
while read -r line; do
    # Check if the line contains a citation
    if [[ $line == @* ]]; then
        # Extract the name of the citation
        name=$(echo "$line" | sed -n 's/.*{\(.*\),/\1/p')
        # Add the name to the list of citations
        citations+=("$name")
    fi
done < /home/artin/Documents/Vshrd/Sources/0000_cite.bib
# Output the list of citations to dmenu
selected=$(printf '%s\n' "${citations[@]}" | rofi -dpi 160 -dmenu -p "select macro" -i -l 20)

# Find the line number of the selected citation
line_number=$(grep -n "$selected" /home/artin/Documents/Vshrd/Sources/0000_cite.bib | cut -d: -f1)
echo $line_number

# Copy the line before the selected citation
sed -n "$((line_number - 1))p" /home/artin/Documents/Vshrd/Sources/0000_cite.bib | sed -n 's/^[^[]*\[\(.*\)\].*$/[\1]/p' | xclip -selection clipboard
