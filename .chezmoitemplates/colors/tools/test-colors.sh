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

    "256-08C:38;5;8"
    "256-09C:38;5;9"
    "256-10C:38;5;10"
    "256-11C:38;5;11"
    "256-12C:38;5;12"
    "256-13C:38;5;13"
    "256-14C:38;5;14"
    "256-15C:38;5;15"

    "256-16C:38;5;16"
    "256-17C:38;5;17"
    "256-18C:38;5;18"
    "256-19C:38;5;19"
    "256-20C:38;5;20"
    "256-21C:38;5;21"
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

notify-send -u low      -i dialog-information "Normal" "This is a normal notification"
notify-send -u normal   -i dialog-warning     "Warning" "This is a warning notification"
notify-send -u critical -i dialog-error       "Error" "This is an error notification"
