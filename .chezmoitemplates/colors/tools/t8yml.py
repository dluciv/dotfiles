#!/usr/bin/env -S uv run --quiet --script --
# /// script
# requires-python = ">=3.9"
# dependencies = [
#     "pyyaml>=6.0",
# ]
# ///
"""
tinted8-to-yaml.py — Converts a tinted8 scheme YAML to a fully expanded
YAML with palette (YAML anchors), ansi colors, ui and syntax sections (YAML aliases).

Implements the tinted8 builder spec 0.2.0-beta9:
- Palette expansion (normal/bright/dim variants)
- Derived colors: orange (from yellow), brown (from yellow), gray (from black+white)
- Variant generation: bright/dim with HSL adjustments (ΔL=0.12)
- Theme resolution: explicit > inherited parent > builder default
- Light variant mirroring for defaults
- ANSI color mapping (ansi_0 to ansi_f)
- Metadata header

Usage:
  tinted8-to-yaml.py <scheme.yaml> [--output result.yaml]

Thanks to Qwen:
  https://chat.qwen.ai/s/t_6846bdb1-d252-4c18-8702-d908ea0cc139?fev=0.2.81
"""

import sys
import os
import argparse
import colorsys
import yaml

DELTA_L = 0.12

# ANSI color mapping: ansi-N → palette token
ANSI_MAPPING = {
    "ansi_0": "black_normal",
    "ansi_1": "red_normal",
    "ansi_2": "green_normal",
    "ansi_3": "yellow_normal",
    "ansi_4": "blue_normal",
    "ansi_5": "magenta_normal",
    "ansi_6": "cyan_normal",
    "ansi_7": "white_normal",
    "ansi_8": "black_bright",
    "ansi_9": "red_bright",
    "ansi_a": "green_bright",
    "ansi_b": "yellow_bright",
    "ansi_c": "blue_bright",
    "ansi_d": "magenta_bright",
    "ansi_e": "cyan_bright",
    "ansi_f": "white_bright",
}

# ---------------------------------------------------------------------------
# Cross-platform config path
# ---------------------------------------------------------------------------

def get_default_output_path():
    """Return the platform-appropriate default output path for the theme file."""
    filename = "current-color-theme.yml"

    if sys.platform == "win32":
        base = os.environ.get("APPDATA")
        if not base:
            base = os.path.join(os.path.expanduser("~"), "AppData", "Roaming")
        return os.path.join(base, filename)

    else:  # UNIX-like
        xdg = os.environ.get("XDG_CONFIG_HOME")
        if not xdg:
            xdg = os.path.join(os.path.expanduser("~"), ".config")
        return os.path.join(xdg, filename)

# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------

def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def rgb_to_hex(r, g, b):
    r = max(0, min(255, int(round(r))))
    g = max(0, min(255, int(round(g))))
    b = max(0, min(255, int(round(b))))
    return "#{:02x}{:02x}{:02x}".format(r, g, b)

def rgb_to_hsl(r, g, b):
    r_n, g_n, b_n = r / 255.0, g / 255.0, b / 255.0
    h, l, s = colorsys.rgb_to_hls(r_n, g_n, b_n)
    return (h * 360.0, s, l)

def hsl_to_rgb(h, s, l):
    h_n = (h / 360.0) % 1.0
    r_n, g_n, b_n = colorsys.hls_to_rgb(h_n, l, s)
    return (r_n * 255.0, g_n * 255.0, b_n * 255.0)

def clamp(x, lo=0.0, hi=1.0):
    return max(lo, min(hi, x))

# ---------------------------------------------------------------------------
# Derived colors (computed when missing from palette)
# ---------------------------------------------------------------------------

def derive_orange(yellow_hex):
    """Orange from yellow: hue shift -10°."""
    h, s, l = rgb_to_hsl(*hex_to_rgb(yellow_hex))
    h_new = (h - 10.0) % 360.0
    return rgb_to_hex(*hsl_to_rgb(h_new, clamp(s), clamp(l)))

def derive_brown(yellow_hex):
    """Brown from yellow: hue -15°, saturation *0.65, lightness -0.30."""
    h, s, l = rgb_to_hsl(*hex_to_rgb(yellow_hex))
    h_new = (h - 15.0) % 360.0
    s_new = clamp(s * 0.65)
    l_new = clamp(l - 0.30)
    return rgb_to_hex(*hsl_to_rgb(h_new, s_new, l_new))

def derive_gray(black_hex, white_hex):
    """Gray from black and white: HSL midpoint."""
    hb, sb, lb = rgb_to_hsl(*hex_to_rgb(black_hex))
    hw, sw, lw = rgb_to_hsl(*hex_to_rgb(white_hex))
    d = ((hb - hw + 540.0) % 360.0) - 180.0
    h_new = (hw + 0.5 * d + 360.0) % 360.0
    s_new = 0.5 * (sb + sw)
    l_new = 0.5 * (lb + lw)
    return rgb_to_hex(*hsl_to_rgb(h_new, clamp(s_new), clamp(l_new)))

# ---------------------------------------------------------------------------
# Variant generation (bright/dim from normal)
# ---------------------------------------------------------------------------

def make_dim(normal_hex):
    """Generate dim variant: L - min(ΔL, L), saturation boost based on L."""
    h, s, l = rgb_to_hsl(*hex_to_rgb(normal_hex))
    l_new = clamp(l - min(DELTA_L, l))
    if l < 0.4:
        k = 1.04
    elif l < 0.7:
        k = 1.07
    else:
        k = 1.10
    s_new = clamp(s * k)
    return rgb_to_hex(*hsl_to_rgb(h, s_new, l_new))

def make_bright(normal_hex):
    """Generate bright variant: L + min(ΔL, 1-L), saturation factor based on L."""
    h, s, l = rgb_to_hsl(*hex_to_rgb(normal_hex))
    l_new = clamp(l + min(DELTA_L, 1.0 - l))
    if l < 0.5:
        k = 1.08
    elif l < 0.8:
        k = 1.00
    else:
        k = 0.90
    s_new = clamp(s * k)
    return rgb_to_hex(*hsl_to_rgb(h, s_new, l_new))

# ---------------------------------------------------------------------------
# Builder default theming properties (from tinted8 spec)
# ---------------------------------------------------------------------------

DEFAULTS = {
    # Syntax
    "syntax.comment":                       "gray_dim",
    "syntax.comment.block":                 "gray_dim",
    "syntax.comment.documentation":         "gray_dim",
    "syntax.comment.line":                  "gray_dim",
    "syntax.constant":                      "orange_normal",
    "syntax.constant.character":            "orange_normal",
    "syntax.constant.character.entity":     "orange_normal",
    "syntax.constant.character.escape":     "orange_normal",
    "syntax.constant.language":             "orange_normal",
    "syntax.constant.numeric":              "orange_normal",
    "syntax.constant.numeric.float":        "orange_normal",
    "syntax.constant.numeric.hex":          "orange_normal",
    "syntax.constant.numeric.integer":      "orange_normal",
    "syntax.constant.other":                "orange_normal",
    "syntax.entity":                        "white_normal",
    "syntax.entity.name":                   "white_normal",
    "syntax.entity.name.class":             "yellow_normal",
    "syntax.entity.name.function":          "blue_normal",
    "syntax.entity.name.function.constructor": "blue_normal",
    "syntax.entity.name.label":             "white_normal",
    "syntax.entity.name.namespace":         "yellow_normal",
    "syntax.entity.name.section":           "cyan_normal",
    "syntax.entity.name.tag":               "white_normal",
    "syntax.entity.name.type":              "cyan_normal",
    "syntax.entity.name.type.class":        "cyan_normal",
    "syntax.entity.name.type.enum":         "cyan_normal",
    "syntax.entity.other":                  "white_normal",
    "syntax.entity.other.attribute-name":   "magenta_normal",
    "syntax.entity.other.inherited-class":  "white_normal",
    "syntax.invalid":                       "red_bright",
    "syntax.invalid.deprecated":            "yellow_bright",
    "syntax.invalid.illegal":               "red_bright",
    "syntax.keyword":                       "magenta_normal",
    "syntax.keyword.control":               "magenta_normal",
    "syntax.keyword.control.flow":          "magenta_normal",
    "syntax.keyword.control.import":        "magenta_normal",
    "syntax.keyword.declaration":           "magenta_normal",
    "syntax.keyword.operator":              "magenta_normal",
    "syntax.keyword.other":                 "magenta_normal",
    "syntax.markup":                        "orange_normal",
    "syntax.markup.bold":                   "orange_normal",
    "syntax.markup.changed":                "yellow_bright",
    "syntax.markup.deleted":                "red_bright",
    "syntax.markup.heading":                "magenta_normal",
    "syntax.markup.inserted":               "green_bright",
    "syntax.markup.italic":                 "orange_normal",
    "syntax.markup.link":                   "yellow_normal",
    "syntax.markup.list":                   "orange_normal",
    "syntax.markup.list.numbered":          "cyan_normal",
    "syntax.markup.list.unnumbered":        "cyan_normal",
    "syntax.markup.quote":                  "orange_normal",
    "syntax.markup.raw":                    "orange_normal",
    "syntax.markup.underline":              "orange_normal",
    "syntax.meta":                          "white_normal",
    "syntax.meta.annotation":               "orange_normal",
    "syntax.meta.block":                    "white_normal",
    "syntax.meta.class":                    "white_normal",
    "syntax.meta.embedded":                 "white_normal",
    "syntax.meta.function":                 "white_normal",
    "syntax.meta.import":                   "white_normal",
    "syntax.meta.object":                   "orange_normal",
    "syntax.meta.preprocessor":             "white_normal",
    "syntax.meta.tag":                      "white_normal",
    "syntax.meta.type":                     "white_normal",
    "syntax.punctuation":                   "white_dim",
    "syntax.punctuation.definition":        "white_normal",
    "syntax.punctuation.definition.comment": "gray_dim",
    "syntax.punctuation.definition.string": "green_normal",
    "syntax.punctuation.section":           "orange_normal",
    "syntax.punctuation.separator":         "white_normal",
    "syntax.source":                        "white_normal",
    "syntax.storage":                       "magenta_normal",
    "syntax.storage.modifier":              "magenta_normal",
    "syntax.storage.type":                  "magenta_normal",
    "syntax.string":                        "green_normal",
    "syntax.string.interpolated":           "green_normal",
    "syntax.string.other":                  "green_normal",
    "syntax.string.quoted":                 "green_normal",
    "syntax.string.quoted.double":          "green_normal",
    "syntax.string.quoted.single":          "green_normal",
    "syntax.string.regexp":                 "red_normal",
    "syntax.string.template":               "green_normal",
    "syntax.string.unquoted":               "green_normal",
    "syntax.support":                       "blue_normal",
    "syntax.support.class":                 "blue_normal",
    "syntax.support.constant":              "magenta_normal",
    "syntax.support.function":              "blue_normal",
    "syntax.support.function.builtin":      "blue_bright",
    "syntax.support.other":                 "blue_normal",
    "syntax.support.type":                  "blue_normal",
    "syntax.support.variable":              "cyan_normal",
    "syntax.text":                          "white_normal",
    "syntax.variable":                      "white_normal",
    "syntax.variable.language":             "magenta_normal",
    "syntax.variable.other":                "white_normal",
    "syntax.variable.other.constant":       "white_normal",
    "syntax.variable.other.object":         "white_normal",
    "syntax.variable.other.object.property": "white_normal",
    "syntax.variable.parameter":            "cyan_bright",
    # UI
    "ui.accent.normal":                     "cyan_normal",
    "ui.border.normal":                     "gray_dim",
    "ui.chrome.background.dark":            "black_dim",
    "ui.chrome.background.light":           "gray_dim",
    "ui.chrome.background.normal":          "black_bright",
    "ui.chrome.foreground.dark":            "white_dim",
    "ui.chrome.foreground.light":           "white_bright",
    "ui.cursor.muted.background":           "gray_bright",
    "ui.cursor.muted.foreground":           "gray_dim",
    "ui.cursor.normal.background":          "white_normal",
    "ui.cursor.normal.foreground":          "black_normal",
    "ui.deprecated":                        "brown_normal",
    "ui.global.background.dark":            "black_dim",
    "ui.global.background.light":           "black_bright",
    "ui.global.background.normal":          "black_normal",
    "ui.global.foreground.dark":            "white_dim",
    "ui.global.foreground.light":           "white_bright",
    "ui.global.foreground.normal":          "white_normal",
    "ui.gutter.background":                 "black_normal",
    "ui.gutter.foreground":                 "white_dim",
    "ui.highlight.button.background":       "black_bright",
    "ui.highlight.button.foreground":       "white_normal",
    "ui.highlight.line.background":         "gray_dim",
    "ui.highlight.line.foreground":         "white_dim",
    "ui.highlight.search.background":       "black_bright",
    "ui.highlight.search.foreground":       "yellow_normal",
    "ui.highlight.text.active_background":  "gray_normal",
    "ui.highlight.text.active_foreground":  "white_normal",
    "ui.highlight.text.background":         "gray_dim",
    "ui.highlight.text.foreground":         "white_normal",
    "ui.indent_guide.active_background":    "gray_dim",
    "ui.indent_guide.background":           "black_bright",
    "ui.link.normal":                       "cyan_normal",
    "ui.selection.background":              "black_bright",
    "ui.selection.foreground":              "white_normal",
    "ui.selection.inactive_background":     "black_bright",
    "ui.status.error":                      "red_normal",
    "ui.status.info":                       "orange_normal",
    "ui.status.success":                    "green_normal",
    "ui.status.warning":                    "yellow_normal",
    "ui.tooltip.background":                "black_dim",
    "ui.tooltip.foreground":                "white_normal",
    "ui.whitespace.foreground":             "gray_normal",
}

# Luminance mirror table for dark→light conversion
LIGHT_MIRROR = {
    "black_dim": "white_bright",
    "black_normal": "white_normal",
    "black_bright": "white_dim",
    "gray_dim": "gray_bright",
    "gray_normal": "gray_normal",
    "gray_bright": "gray_dim",
    "white_dim": "black_bright",
    "white_normal": "black_normal",
    "white_bright": "black_dim",
}

def mirror_for_light(color_token):
    """Convert a dark-default token to its light equivalent."""
    return LIGHT_MIRROR.get(color_token, color_token)

# ---------------------------------------------------------------------------
# Palette expansion
# ---------------------------------------------------------------------------

BASE_COLORS = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
DERIVED_COLORS = ["orange", "brown", "gray"]
ALL_COLORS = BASE_COLORS + DERIVED_COLORS
VARIANTS = ["normal", "bright", "dim"]

def expand_palette(palette):
    """
    Expand palette:
    1. Treat bare color names as "-normal" (e.g. "black" → "black-normal")
    2. Compute missing derived colors (orange, brown, gray)
    3. Generate missing bright/dim variants from normal
    Preserves explicitly provided variants.
    """
    # Normalize bare names to -normal, hyphens to underscores
    normalized = {}
    for key, val in palette.items():
        key = key.replace("-", "_")
        if key in BASE_COLORS + DERIVED_COLORS:
            normalized[f"{key}_normal"] = val
        else:
            normalized[key] = val

    result = {}

    # Step 1: Collect explicit base colors
    for color in BASE_COLORS:
        n_key = f"{color}_normal"
        if n_key in normalized:
            result[n_key] = normalized[n_key]
        else:
            print(f"Warning: missing required base color '{color}'", file=sys.stderr)

    # Step 2: Derive missing orange/brown/gray
    if "orange_normal" not in normalized:
        if "yellow_normal" in result:
            result["orange_normal"] = derive_orange(result["yellow_normal"])
        else:
            print("Warning: cannot derive orange (no yellow)", file=sys.stderr)
    else:
        result["orange_normal"] = normalized["orange_normal"]

    if "brown_normal" not in normalized:
        if "yellow_normal" in result:
            result["brown_normal"] = derive_brown(result["yellow_normal"])
    else:
        result["brown_normal"] = normalized["brown_normal"]

    if "gray_normal" not in normalized:
        if "black_normal" in result and "white_normal" in result:
            result["gray_normal"] = derive_gray(result["black_normal"], result["white_normal"])
    else:
        result["gray_normal"] = normalized["gray_normal"]

    # Step 3: Generate bright/dim for all colors (preserve if explicit)
    for color in ALL_COLORS:
        n_key = f"{color}_normal"
        if n_key not in result:
            continue
        b_key = f"{color}_bright"
        if b_key in normalized:
            result[b_key] = normalized[b_key]
        else:
            result[b_key] = make_bright(result[n_key])
        d_key = f"{color}_dim"
        if d_key in normalized:
            result[d_key] = normalized[d_key]
        else:
            result[d_key] = make_dim(result[n_key])

    return result

# ---------------------------------------------------------------------------
# Theme resolution
# ---------------------------------------------------------------------------

def flatten_section(section, section_prefix):
    """
    Flatten nested YAML section into dot-separated keys with section prefix.
    e.g. {"entity": {"name": {"function": "#abc"}}} with prefix "syntax"
    → {"syntax.entity.name.function": "#abc"}
    """
    result = {}
    if not section:
        return result

    def _flatten(d, prefix=""):
        for key, val in d.items():
            key = key.replace("-", "_")
            full_key = f"{prefix}.{key}" if prefix else key
            if isinstance(val, dict):
                _flatten(val, full_key)
            else:
                final_key = f"{section_prefix}.{full_key}" if section_prefix else full_key
                result[final_key] = val

    _flatten(section)
    return result

def _as_token(val, palette):
    """Return palette token with hyphens normalized to underscores, or None."""
    if isinstance(val, str) and val.replace("-", "_") in palette:
        return val.replace("-", "_")
    return None


def resolve_theming_property(key, flat_scheme_section, palette, is_dark):
    """
    Resolve a theming property following the priority chain:
    1. Exact scheme value (hex or palette token)
    2. Inherited parent value (walk up the dot-separated path)
    3. Builder default (with light-variant mirroring)

    Returns ("token", "color-variant") or ("hex", "#rrggbb").
    """
    # 1. Exact match
    if key in flat_scheme_section:
        val = flat_scheme_section[key]
        if isinstance(val, str) and val.startswith("#"):
            return ("hex", val)
        token = _as_token(val, palette)
        if token:
            return ("token", token)
        return ("hex", str(val))

    # 2. Inherited parent
    parts = key.split(".")
    for i in range(len(parts) - 1, 0, -1):
        parent = ".".join(parts[:i])
        if parent in flat_scheme_section:
            val = flat_scheme_section[parent]
            if isinstance(val, str) and val.startswith("#"):
                return ("hex", val)
            token = _as_token(val, palette)
            if token:
                return ("token", token)
            return ("hex", str(val))

    # 3. Builder default
    if key in DEFAULTS:
        default_token = DEFAULTS[key]
        if not is_dark:
            default_token = mirror_for_light(default_token)
        if default_token in palette:
            return ("token", default_token)

    return ("token", "white_normal")

# ---------------------------------------------------------------------------
# YAML output with anchors and aliases
# ---------------------------------------------------------------------------

def output_yaml(palette, syntax_resolved, ui_resolved, scheme_meta, variant):
    """Generate YAML output with metadata header, palette anchors, ansi mapping, and syntax/ui aliases."""
    lines = []

    # Metadata header
    lines.append("# =============================================================================")
    lines.append("# Meta Information")
    lines.append("# =============================================================================")
    if scheme_meta:
        meta_fields = [
            ("system", scheme_meta.get("system")),
            ("name", scheme_meta.get("name")),
            ("family", scheme_meta.get("family")),
            ("style", scheme_meta.get("style")),
            ("slug", scheme_meta.get("slug")),
            ("author", scheme_meta.get("author")),
            ("theme_author", scheme_meta.get("theme-author")),
            ("description", scheme_meta.get("description")),
            ("supported_styling_version", scheme_meta.get("supports", {}).get("styling-spec")),
            ("supported_builder_version", scheme_meta.get("supports", {}).get("builder-spec")),
        ]
        for field, value in meta_fields:
            if value:
                lines.append(f"# {field}: {value}")
    lines.append(f"# variant: {variant}")
    lines.append("# =============================================================================")
    lines.append("")

    # Palette section (with YAML anchors, grouped by color)
    lines.append("palette:")
    for color in ALL_COLORS:
        variants = {}
        for v in VARIANTS:
            k = f"{color}_{v}"
            if k in palette:
                variants[v] = palette[k]
        if not variants:
            continue
        lines.append(f"  {color}:")
        for v in VARIANTS:
            if v not in variants:
                continue
            val = str(variants[v]).lstrip("#").lower()
            token = f"{color}_{v}"
            lines.append(f"    {v}: &{token} '{val}'")

    lines.append("")

    # ANSI colors section
    lines.append("ansi:")
    ansi_keys = ["ansi_0", "ansi_1", "ansi_2", "ansi_3", "ansi_4", "ansi_5", "ansi_6", "ansi_7",
                  "ansi_8", "ansi_9", "ansi_a", "ansi_b", "ansi_c", "ansi_d", "ansi_e", "ansi_f"]
    for ansi_key in ansi_keys:
        palette_token = ANSI_MAPPING[ansi_key]
        if palette_token in palette:
            lines.append(f"  {ansi_key}: *{palette_token}")
        else:
            # Fallback to hex if palette token somehow missing
            val = str(palette.get(palette_token, "#000000")).lstrip("#").lower()
            lines.append(f"  {ansi_key}: '{val}'")

    lines.append("")

    def write_nested(lines, prefix, data, base_indent=2):
        """Write a flat dict of resolved properties as nested YAML with aliases."""
        tree = {}
        for key in sorted(data.keys()):
            if not key.startswith(prefix + "."):
                continue
            rest = key[len(prefix) + 1:]
            parts = rest.split(".")

            node = tree
            for part in parts[:-1]:
                if part not in node:
                    node[part] = {}
                elif not isinstance(node[part], dict):
                    # Convert leaf to dict with "default" key for inheritance
                    node[part] = {"default": node[part]}
                node = node[part]

            leaf = parts[-1]
            ref_type, ref_val = data[key]
            if leaf not in node:
                node[leaf] = (ref_type, ref_val)
            else:
                if isinstance(node[leaf], dict):
                    node[leaf]["default"] = (ref_type, ref_val)
                else:
                    node[leaf] = {"default": (ref_type, ref_val)}

        def _write_tree(node, indent):
            default_val = None
            leaves = []
            subtrees = []

            for k, v in node.items():
                if k == "default":
                    default_val = v
                elif isinstance(v, tuple) and len(v) == 2 and isinstance(v[0], str):
                    leaves.append((k, v))
                elif isinstance(v, dict):
                    subtrees.append((k, v))

            # Write default value first (if node has both a value and children)
            if default_val is not None:
                ref_type, ref_val = default_val
                if ref_type == "token":
                    lines.append(" " * indent + f"default: *{ref_val}")
                else:
                    lines.append(" " * indent + f"default: '{str(ref_val).lstrip('#')}'")

            for k, v in sorted(leaves):
                ref_type, ref_val = v
                if ref_type == "token":
                    lines.append(" " * indent + f"{k.replace('-', '_')}: *{ref_val}")
                else:
                    lines.append(" " * indent + f"{k.replace('-', '_')}: '{str(ref_val).lstrip('#')}'")

            for k, v in sorted(subtrees):
                lines.append(" " * indent + f"{k.replace('-', '_')}:")
                _write_tree(v, indent + 2)

        _write_tree(tree, base_indent)

    # UI section
    lines.append("ui:")
    write_nested(lines, "ui", ui_resolved)

    lines.append("")

    # Syntax section
    lines.append("syntax:")
    write_nested(lines, "syntax", syntax_resolved)

    return "\n".join(lines) + "\n"

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Convert tinted8 scheme to expanded YAML with anchors/aliases. "
                    "Saves to platform config directory by default."
    )
    parser.add_argument("scheme", help="Path to tinted8 scheme YAML file")
    parser.add_argument(
        "--output", "-o",
        help=f"Output file path (default: {get_default_output_path()})"
    )
    args = parser.parse_args()

    with open(args.scheme) as f:
        scheme = yaml.safe_load(f)

    variant = scheme.get("variant", "dark")
    is_dark = variant == "dark"
    palette_input = scheme.get("palette", {})
    syntax_input = scheme.get("syntax", {})
    ui_input = scheme.get("ui", {})
    scheme_meta = scheme.get("scheme", {})

    palette = expand_palette(palette_input)
    flat_syntax = flatten_section(syntax_input, "syntax")
    flat_ui = flatten_section(ui_input, "ui")

    # Resolve all syntax properties (scheme keys + all defaults)
    syntax_resolved = {}
    all_syntax_keys = set(flat_syntax.keys()) | {
        k for k in DEFAULTS if k.startswith("syntax.")
    }
    for key in all_syntax_keys:
        resolved = resolve_theming_property(key, flat_syntax, palette, is_dark)
        syntax_resolved[key] = resolved

    # Resolve all UI properties (scheme keys + all defaults)
    ui_resolved = {}
    all_ui_keys = set(flat_ui.keys()) | {
        k for k in DEFAULTS if k.startswith("ui.")
    }
    for key in all_ui_keys:
        resolved = resolve_theming_property(key, flat_ui, palette, is_dark)
        ui_resolved[key] = resolved

    result = output_yaml(palette, syntax_resolved, ui_resolved, scheme_meta, variant)

    output_path = args.output or get_default_output_path()

    # Ensure parent directory exists
    parent = os.path.dirname(os.path.abspath(output_path))
    if parent:
        os.makedirs(parent, exist_ok=True)

    with open(output_path, "w") as f:
        f.write(result)

    print(f"✓ Theme saved to: {output_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
