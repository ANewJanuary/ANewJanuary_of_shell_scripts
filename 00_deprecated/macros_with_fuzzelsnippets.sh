#!/usr/bin/env bash
# macro-pick — fuzzel-native snippet picker for niri/Wayland
# Bind to Super+i in niri config:
#   Super+i { spawn "bash" "-c" "/path/to/macro-pick"; }
#
# Placeholder syntax in snippet files:
#   $word or ${word}        — prompts for a value via fuzzel
#   ${word:default}         — prompts with a pre-filled default value
#   $TAB                    — cursor lands here after typing
#                             (everything after the first $TAB is typed,
#                              then cursor is moved left to that position)
#
# Dependencies: fuzzel, wtype
#   sudo dnf install fuzzel wtype

MACRO_DIR="${MACRO_DIR:-$HOME/Vshrd/macros}"

cd "$MACRO_DIR" || exit 1

# ── 1. Pick a snippet via fuzzel dmenu ───────────────────────────────────────
file=$(ls | fuzzel --dmenu \
    --prompt "snippet> " \
    --lines 15 \
    --width 40)

[ -z "$file" ] || [ ! -f "$file" ] && exit 0

content=$(cat "$file")

# ── 2. Resolve placeholders ───────────────────────────────────────────────────
# Extract unique placeholders in document order
placeholders=$(printf '%s' "$content" \
    | grep -oE '\$\{[a-zA-Z_][a-zA-Z0-9_]*(:[^}]*)?\}|\$[a-zA-Z_][a-zA-Z0-9_]*' \
    | awk '!seen[$0]++')

declare -A values
last_value=""

while IFS= read -r ph; do
    [ -z "$ph" ] && continue

    # Parse name and optional default from ${name:default}
    if [[ "$ph" =~ ^\$\{([a-zA-Z_][a-zA-Z0-9_]*):([^}]*)\}$ ]]; then
        name="${BASH_REMATCH[1]}"
        default="${BASH_REMATCH[2]}"
    elif [[ "$ph" =~ ^\$\{([a-zA-Z_][a-zA-Z0-9_]*)\}$ ]]; then
        name="${BASH_REMATCH[1]}"
        default=""
    else
        name="${ph#\$}"
        default=""
    fi

    # Use fuzzel --prompt-only for free-text input.
    # Pre-fill with default if set, otherwise with last_value for quick reuse.
    prefill="${default:-$last_value}"

    input=$(echo "$prefill" | fuzzel --dmenu \
        --prompt "$name: " \
        --lines 0 \
        --width 40)

    # Cancelled mid-way → abort entirely
    [ $? -ne 0 ] && exit 0

    values["$ph"]="$input"
    last_value="$input"
done <<< "$placeholders"

# ── 3. Apply substitutions ────────────────────────────────────────────────────
for ph in "${!values[@]}"; do
    escaped_val=$(printf '%s' "${values[$ph]}" | sed 's/[&/\]/\\&/g')
    escaped_ph=$(printf '%s' "$ph" | sed 's/[.[\*^$]/\\&/g; s/|/\\|/g')
    content=$(printf '%s' "$content" | sed "s|${escaped_ph}|${escaped_val}|g")
done

# ── 4. Tab-stop handling ──────────────────────────────────────────────────────
# Split on $TAB: type everything, then move cursor left past the trailing text.
tab_count=$(grep -o '\$TAB' <<< "$content" | wc -l)

if [ "$tab_count" -gt 0 ]; then
    IFS=$'\001' read -ra parts <<< "$(printf '%s' "$content" | sed 's/\$TAB/\x01/g')"

    first_part="${parts[0]}"
    after_first=""
    for (( i=1; i<${#parts[@]}; i++ )); do
        after_first+="${parts[$i]}"
        # Re-insert a tab character between later stops (if any)
        (( i < ${#parts[@]} - 1 )) && after_first+=$'\t'
    done

    chars_after=$(printf '%s' "$after_first" | wc -m)
    full_typed="${first_part}${after_first}"

    sleep 0.1
    printf '%s' "$full_typed" | wtype -

    if [ "$chars_after" -gt 0 ]; then
        for (( i=0; i<chars_after; i++ )); do
            wtype -P left -p left
        done
    fi
else
  sleep 0.1
  printf '%s' "$full_typed" | wtype -
  sleep 0.05
  wtype "jk'[V']="
fi
