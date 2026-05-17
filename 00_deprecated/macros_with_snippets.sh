#!/usr/bin/env bash

MACRO_DIR="$HOME/Vshrd/macros"

cd "$MACRO_DIR"

# Select snippet
file=$(fzf -e)
[ -z "$file" ] && exit 0

cat $file

content=$(cat "$file")

# Find unique placeholders like $word
placeholders=$(printf "%s" "$content" \
  | grep -o '\$[a-z]\+')
# | sort -u)

if [ -z "$placeholders" ]; then
  printf "%s" "$content" | wl-copy
  echo "Snippet copied to clipboard (no placeholders)."
  exit 0
fi

declare -A values
last_value=""

for ph in $placeholders; do
  name="${ph#\$}"

  # Prompt user
  if [ -n "$last_value" ]; then
    read -rp "Value for $name (Enter = reuse '$last_value'): " input
  else
    read -rp "Value for $name: " input
  fi

  if [ -z "$input" ]; then
    input="$last_value"
  fi

  values["$ph"]="$input"
  last_value="$input"
done

# Replace placeholders
for ph in "${!values[@]}"; do
  content=$(printf "%s" "$content" | sed "s|$ph|${values[$ph]}|g")
done

# Copy to clipboard
printf "%s" "$content" | wl-copy

echo "Snippet expanded and copied to clipboard."
