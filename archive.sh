#!/bin/sh
input_file="/home/artin/Vshrd/Vault/Index/agenda.md"
output_file="/home/artin/Vshrd/Vault/Index/archive.md"

# Temporary file to hold matched blocks
matched_blocks=$(mktemp)

# Use awk to extract - [ ] blocks (with indented lines)
awk '
  BEGIN { in_block = 0 }
  /^- \[X\]/ {
    if (in_block) print "";  # Separate previous block
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
    in_block = 0;
  }
' "$input_file" > "$matched_blocks"

# If matched blocks exist, append them with date header to output file
if [ -s "$matched_blocks" ]; then
  current_date="# $(date +"%Y-%m-%d")"
  {
    echo "$current_date"
    cat "$matched_blocks"
    echo ""
  } >> "$output_file"
  echo "Blocks extracted and saved to $output_file"
else
  nvim "/home/artin/Vshrd/Vault/Index/archive.md"
fi

# Use awk again to remove matched blocks from input file
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
    in_block = 0;
    print $0;
  }
' "$input_file" > "$input_file.tmp" && mv "$input_file.tmp" "$input_file"

# Clean up
rm "$matched_blocks"
