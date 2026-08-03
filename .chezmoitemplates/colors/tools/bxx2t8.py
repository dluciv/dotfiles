#!/usr/bin/env -S uv run --quiet --script --
# /// script
# requires-python = ">=3.9"
# dependencies = [
#     "pyyaml>=6.0",
# ]
# ///
"""
base-to-tinted8.py — Converts Base16/Base24 schemes to Tinted8 format.

Uses structural mapping (base08→red, base0B→green, etc.) as primary strategy,
with color-similarity fallback for edge cases.

Usage:
  base-to-tinted8.py <base16-or-base24.yaml> [--output tinted8-scheme.yaml]

Pipeline:
  base-to-tinted8.py eighties.yaml -o tinted8.yaml
  tinted8-to-yaml.py tinted8.yaml
"""

import sys
import os
import argparse
import yaml

# ---------------------------------------------------------------------------
# Base16/Base24 → Tinted8 structural mapping
# ---------------------------------------------------------------------------

# Base16 semantic roles → Tinted8 color names
BASE16_TO_TINTED8 = {
    "base00": "black",       # Default background
    "base05": "white",       # Default foreground
    "base08": "red",         # Variables, errors
    "base09": "orange",      # Integers, booleans
    "base0A": "yellow",      # Classes, search
    "base0B": "green",       # Strings
    "base0C": "cyan",        # Support, regex
    "base0D": "blue",        # Functions, methods
    "base0E": "magenta",     # Keywords, operators
    "base0F": "brown",       # Deprecated, embedded
}

# Base24 bright variants → Tinted8 bright colors
BASE24_BRIGHT = {
    "base12": "red-bright",
    "base13": "yellow-bright",
    "base14": "green-bright",
    "base15": "cyan-bright",
    "base16": "blue-bright",
    "base17": "magenta-bright",
}

# Gray candidates (in priority order)
GRAY_CANDIDATES = ["base03", "base04"]

# Black dim candidates
BLACK_DIM_CANDIDATES = ["base01", "base11", "base10"]

# White bright candidates
WHITE_BRIGHT_CANDIDATES = ["base06", "base07"]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def clean(s):
    """Strip whitespace from string values."""
    if isinstance(s, str):
        return s.strip()
    return s

def clean_palette(palette):
    """Clean palette keys and values."""
    return {clean(k): clean(v) for k, v in palette.items()}

def hex_to_hsl(h):
    """Convert hex to HSL."""
    h = h.lstrip("#")
    r, g, b = int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0
    mx, mn = max(r, g, b), min(r, g, b)
    l = (mx + mn) / 2.0
    if mx == mn:
        hue = sat = 0.0
    else:
        d = mx - mn
        sat = d / (2.0 - mx - mn) if l > 0.5 else d / (mx + mn)
        if mx == r:
            hue = (g - b) / d + (6.0 if g < b else 0.0)
        elif mx == g:
            hue = (b - r) / d + 2.0
        else:
            hue = (r - g) / d + 4.0
        hue *= 60.0
    return (hue, sat, l)

def color_distance(hsl1, hsl2):
    """Weighted HSL distance for color similarity."""
    h1, s1, l1 = hsl1
    h2, s2, l2 = hsl2
    # Hue distance (wrap-aware)
    dh = abs(h1 - h2)
    dh = min(dh, 360.0 - dh) / 180.0
    ds = abs(s1 - s2)
    dl = abs(l1 - l2)
    # Weight hue more for chromatic colors, lightness for achromatic
    if s1 < 0.1 and s2 < 0.1:
        return dl * 2.0  # Achromatic: lightness matters most
    return dh * 2.0 + ds * 1.0 + dl * 1.5

# ---------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------

def convert_base_to_tinted8(scheme):
    """Convert a Base16/Base24 scheme to Tinted8 format."""
    system = clean(scheme.get("system", ""))
    name = clean(scheme.get("name", "Unknown"))
    author = clean(scheme.get("author", "Unknown"))
    variant = clean(scheme.get("variant", "dark"))
    palette = clean_palette(scheme.get("palette", {}))

    is_base24 = system.lower().startswith("base24")

    # Build Tinted8 palette
    t8_palette = {}

    # Step 1: Structural mapping for base colors
    for base_key, t8_name in BASE16_TO_TINTED8.items():
        if base_key in palette:
            t8_palette[t8_name] = palette[base_key]

    # Step 2: Gray — pick from candidates or derive
    gray_set = False
    for candidate in GRAY_CANDIDATES:
        if candidate in palette:
            t8_palette["gray"] = palette[candidate]
            gray_set = True
            break

    # Step 3: Black dim — pick from candidates
    for candidate in BLACK_DIM_CANDIDATES:
        if candidate in palette:
            t8_palette["black-dim"] = palette[candidate]
            break

    # Step 4: White bright — pick from candidates
    for candidate in WHITE_BRIGHT_CANDIDATES:
        if candidate in palette:
            t8_palette["white-bright"] = palette[candidate]
            break

    # Step 5: Bright variants
    if is_base24:
        # Base24 has explicit bright colors
        for base_key, t8_key in BASE24_BRIGHT.items():
            if base_key in palette:
                t8_palette[t8_key] = palette[base_key]
    # For Base16, bright will be computed by the main script

    # Step 6: Handle missing white — use base06 or base07
    if "white" not in t8_palette:
        for candidate in ["base06", "base07", "base05"]:
            if candidate in palette:
                t8_palette["white"] = palette[candidate]
                break

    # Build output scheme
    output = {
        "scheme": {
            "system": "tinted8",
            "supports": {"styling-spec": "0.2.0"},
            "name": name,
            "author": author,
        },
        "variant": variant,
        "palette": {},
    }

    # Order palette keys
    order = [
        "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
        "orange", "brown", "gray",
        "black-bright", "red-bright", "green-bright", "yellow-bright",
        "blue-bright", "magenta-bright", "cyan-bright", "white-bright",
        "black-dim", "red-dim", "green-dim", "yellow-dim",
        "blue-dim", "magenta-dim", "cyan-dim", "white-dim",
    ]

    for key in order:
        if key in t8_palette:
            output["palette"][key] = t8_palette[key]

    return output

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Convert Base16/Base24 scheme to Tinted8 format"
    )
    parser.add_argument("input", help="Path to Base16/Base24 YAML file")
    parser.add_argument("--output", "-o", help="Output file (default: stdout)")
    args = parser.parse_args()

    with open(args.input) as f:
        scheme = yaml.safe_load(f)

    result = convert_base_to_tinted8(scheme)

    output_str = yaml.dump(result, default_flow_style=False, sort_keys=False, allow_unicode=True)

    if args.output:
        with open(args.output, "w") as f:
            f.write(output_str)
        print(f"✓ Converted to: {args.output}", file=sys.stderr)
    else:
        sys.stdout.write(output_str)


if __name__ == "__main__":
    main()
