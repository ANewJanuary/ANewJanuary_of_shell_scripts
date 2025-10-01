#!/bin/bash

# This script goes through my agenda folder, searches for all TODOS
# that have been checked, and puts them in an archive.

agenda_folder="/home/artin/Vshrd/Vault/Agenda"
output_file="/home/artin/Vshrd/Vault/Agenda/archive.md"

# Temporary file to hold matched blocks
matched_blocks=$(mktemp)

# Function to process a single file
process_file() {
    local input_file="$1"
    
    # Use awk to extract - [X] blocks (with indented lines)
    awk '
      BEGIN { in_block = 0 }
      /^- \[X\]/ {
          if (in_block) print "";  # Separate previous block
          print "## Source: '"$(basename "$input_file")"'";
          print $0;
          in_block = 1;
          next;
      }
      /^[ \t]+/ {
          if (in_block) {
              print $0;
              next;
          }
      }
      {
          if (in_block) print "";  # Add blank line after block
          in_block = 0;
      }
    ' "$input_file" >> "$matched_blocks"
}

# Function to remove matched blocks from a file
clean_file() {
    local input_file="$1"
    
    # Use awk to remove matched blocks from input file
    awk '
      BEGIN { in_block = 0 }
      /^- \[X\]/ {
          in_block = 1;
          next;
      }
      /^[ \t]+/ {
          if (in_block) next;
      }
      {
          if (in_block) {
              in_block = 0;
          }
          print $0;
      }
    ' "$input_file" > "$input_file.tmp" && mv "$input_file.tmp" "$input_file"
}

# Find all markdown files in the agenda folder and process them
found_todos=0
while IFS= read -r -d '' file; do
    if grep -q "^- \[X\]" "$file"; then
        process_file "$file"
        clean_file "$file"
        found_todos=1
        echo "Processed completed TODOs in: $(basename "$file")"
    fi
done < <(find "$agenda_folder" -name "*.md" -type f -print0)

# If matched blocks exist, append them with date header to output file
if [ -s "$matched_blocks" ]; then
    current_date="# $(date +"%Y-%m-%d")"
    {
        echo "$current_date"
        cat "$matched_blocks"
        echo ""
    } >> "$output_file"
    echo "Completed TODOs extracted from folder and saved to $output_file"
else
    echo "No completed TODOs found in agenda folder."
    nvim "/home/artin/Vshrd/Vault/Index/archive.md"
fi

# Clean up
rm "$matched_blocks"

# Open agenda folder in neovim
search_todos() {
    local dir="/home/artin/Vshrd/Vault/Agenda"
    local selected_result
    
    # Search for [!TODO], ignoring common directories
    selected_result=$(rg --fixed-strings -e "- [ ]"  \
        --color=always \
        --line-number \
        --no-heading \
        "$dir" \
        --glob "!node_modules" \
        --glob "!.git" \
        --glob "!vendor" \
        --glob "!target" \
        --glob "!dist" \
        --glob "!shell-scripts" \
        --glob "!build" | \
        fzf --ansi \
            --preview="echo {} | cut -d: -f1 | xargs bat --color=always --highlight-line \$(echo {} | cut -d: -f2) 2>/dev/null || echo {} | cut -d: -f1 | xargs head -n 20" \
            --preview-window=top:60%:wrap \
            --border \
            --header="Searching for [!TODO] (ignoring node_modules, .git, vendor, etc.)")
    
    # Extract filename and line number
    if [[ -n "$selected_result" ]]; then
        local file=$(echo "$selected_result" | cut -d: -f1)
        local line=$(echo "$selected_result" | cut -d: -f2)
        
        echo "Opening: $file (line $line)"
        nvim "+$line" "$file"
    else
        ranger /home/artin/Vshrd/Vault/Agenda
    fi
}

search_todos "$@"
