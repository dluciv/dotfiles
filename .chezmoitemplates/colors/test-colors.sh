#!/usr/bin/env bash

# Print header
printf "\n%s%-15s %-20s %-20s %-20s%s\n" "$(tput bold)" "Color" "Dim (2;)" "Normal (0;)" "Bright (1;)" "$(tput sgr0)"
printf "%s\n" "----------------------------------------------------------------------------"

# Array of color names and their base ANSI codes
colors=(
    "Black:30"
    "Red:31"
    "Green:32"
    "Yellow:33"
    "Blue:34"
    "Magenta:35"
    "Cyan:36"
    "White:37"
)

# Loop through each color and apply modifiers
for entry in "${colors[@]}"; do
    name="${entry%%:*}"
    code="${entry#*:}"

    printf "\e[0;%sm%-20s\e[0s "       37 "$name"
    printf "\e[2;%sm%-20s\e[0s "  "$code" "Sample Text"
    printf "\e[0;%sm%-20s\e[0s "  "$code" "Sample Text"
    printf "\e[1;%sm%-20s\e[0s\n" "$code" "Sample Text"
done
printf "\n"
