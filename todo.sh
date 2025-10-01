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
        echo "No selection made."
    fi
}

search_todos "$@"
