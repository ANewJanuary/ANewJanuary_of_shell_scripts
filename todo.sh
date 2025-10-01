#!/bin/bash

# Enhanced version that ignores multiple common directories

search_todos() {
    local dir="${1:-.}"
    local selected_result
    
    # Search for [!TODO], ignoring common directories
    selected_result=$(rg "\[\!TODO\]" \
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
        # Format: show shortened path + line number + content
        awk -F: '{
            n = split($1, parts, "/");
            if (n <= 3) {
                short_path = $1;
            } else {
                short_path = "..." parts[n-2] "/" parts[n-1] "/" parts[n];
            }
            # Store: display_text | full_path:line:content
            printf "%s:%s | %s:%s:%s\n", short_path, $2, $1, $2, $3;
        }' | \
        fzf --ansi \
            --delimiter="|" \
            --with-nth=1 \
            --preview="echo {2} | cut -d: -f3-" \
            --preview-window=top:wrap \
            --border)
    
    # Extract filename and line number
    if [[ -n "$selected_result" ]]; then
        # Extract the full path from after the | separator
        local full_info=$(echo "$selected_result" | cut -d'|' -f2 | sed 's/^ //')
        local file=$(echo "$full_info" | cut -d: -f1)
        local line=$(echo "$full_info" | cut -d: -f2)
        
        echo "Opening: $file (line $line)"
        nvim "+$line" "$file"
    else
        echo "No selection made."
    fi
}

search_todos "$@"
