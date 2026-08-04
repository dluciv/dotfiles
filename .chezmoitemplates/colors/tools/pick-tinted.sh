#!/usr/bin/env bash
# https://chat.qwen.ai/s/t_0d43629f-9582-4d86-baff-9f5098e48c43?fev=0.2.81

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO_URL="https://github.com/tinted-theming/schemes.git"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tinted-theming-schemes"

SCRIPTS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi/.chezmoitemplates/colors/tools"
BXX2T8="$SCRIPTS_DIR/bxx2t8.py"
T8YML="$SCRIPTS_DIR/t8yml.py"

# Field separator for fzf (unit separator, unlikely to appear in paths)
SEP=$'\x1f'

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
for cmd in git fzf find; do
    command -v "$cmd" &>/dev/null || { echo "Error: '$cmd' not found in PATH" >&2; exit 1; }
done

[[ -x "$BXX2T8" ]] || { echo "Error: $BXX2T8 not found or not executable" >&2; exit 1; }
[[ -x "$T8YML"  ]] || { echo "Error: $T8YML not found or not executable" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Clone or update repository
# ---------------------------------------------------------------------------
if [[ -d "$CACHE_DIR/.git" ]]; then
    echo "Updating $CACHE_DIR ..." >&2
    git -C "$CACHE_DIR" pull --quiet --ff-only || {
        echo "Warning: git pull failed, using existing repo" >&2
    }
else
    echo "Cloning tinted-theming/schemes ..." >&2
    git clone --depth 1 --quiet "$REPO_URL" "$CACHE_DIR" || {
        echo "Error: git clone failed" >&2
        exit 1
    }
fi

# ---------------------------------------------------------------------------
# Find all theme files and detect their system type
# ---------------------------------------------------------------------------
declare -a entries=()

# tinted8 themes
while IFS= read -r -d '' file; do
    entries+=("tinted8$SEP$file")
done < <(find "$CACHE_DIR/tinted8" -name '*.yaml' -print0 2>/dev/null)

# base16 themes
while IFS= read -r -d '' file; do
    entries+=("base16$SEP$file")
done < <(find "$CACHE_DIR/base16" -name '*.yaml' -print0 2>/dev/null)

# base24 themes
while IFS= read -r -d '' file; do
    entries+=("base24$SEP$file")
done < <(find "$CACHE_DIR/base24" -name '*.yaml' -print0 2>/dev/null)

if [[ ${#entries[@]} -eq 0 ]]; then
    echo "Error: no theme files found in $CACHE_DIR" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Interactive selection with fzf (with preview)
# ---------------------------------------------------------------------------
# Build fzf input: "system\tname\tpath" (tab-separated for display, path in 3rd field)
fzf_input=""
for entry in "${entries[@]}"; do
    IFS="$SEP" read -r system filepath <<< "$entry"
    bname=$(basename "$filepath" .yaml)
    fzf_input+="${system}"$'\t'"${bname}"$'\t'"${filepath}"$'\n'
done

# fzf config:
#   --with-nth=1,2    : show only system and name columns
#   --delimiter='\t'  : split fields by tab
#   {3} in preview    : 3rd field = full filepath
selection=$(echo "$fzf_input" \
    | fzf --prompt="Select theme> " \
          --header="SYSTEM"$'\t'"NAME" \
          --layout=reverse \
          --height=~60% \
          --delimiter=$'\t' \
          --with-nth=1,2 \
          --preview-window='right:50%' \
          --preview='head -40 {3}') || { echo "Aborted." >&2; exit 0; }

# Extract the full filepath from the 3rd field
selected_file=$(echo "$selection" | cut -d$'\t' -f3)
selected_system=$(echo "$selection" | cut -d$'\t' -f1)
selected_name=$(echo "$selection" | cut -d$'\t' -f2)

if [[ -z "$selected_file" ]]; then
    echo "Error: could not resolve selected theme" >&2
    exit 1
fi

echo "Selected: $selected_system / $selected_name" >&2
echo "File:     $selected_file" >&2

# ---------------------------------------------------------------------------
# Run the appropriate pipeline
# ---------------------------------------------------------------------------
case "$selected_system" in
    tinted8)
        echo "Running: t8yml.py ..." >&2
        "$T8YML" "$selected_file"
        ;;
    base16|base24)
        echo "Running: bxx2t8.py | t8yml.py ..." >&2
        "$BXX2T8" "$selected_file" | "$T8YML" /dev/stdin
        if [[ $? == 0 ]]; then
            chezmoi init --apply
        fi
        ;;
    *)
        echo "Error: unknown system '$selected_system'" >&2
        exit 1
        ;;
esac
