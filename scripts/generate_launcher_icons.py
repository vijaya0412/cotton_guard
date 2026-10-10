"""
Cotton Guard - Android Launcher Icon Generator
Generates legacy and adaptive Android launcher icons from the high-resolution logo.
Supports specifying any custom uploaded image as an argument.
"""

import os
import sys
from PIL import Image, ImageDraw

DENSITIES = {
    "mdpi": {"legacy": 48, "foreground": 108},
    "hdpi": {"legacy": 72, "foreground": 162},
    "xhdpi": {"legacy": 96, "foreground": 216},
    "xxhdpi": {"legacy": 144, "foreground": 324},
    "xxxhdpi": {"legacy": 192, "foreground": 432},
}

def generate_icons(source_path="assets/images/cotton_guard_logo.png"):
    if not os.path.exists(source_path):
        print(f"Error: Source image not found at {source_path}")
        sys.exit(1)

    print(f"Loading source icon: {source_path}")
    source = Image.open(source_path).convert("RGBA")
    w, h = source.size
    print(f"Source image dimensions: {w}x{h}, mode: {source.mode}")

    res_dir = os.path.join("android", "app", "src", "main", "res")
    os.makedirs(res_dir, exist_ok=True)

    # 1. Colors & Values for Adaptive Background
    values_dir = os.path.join(res_dir, "values")
    os.makedirs(values_dir, exist_ok=True)
    colors_xml_path = os.path.join(values_dir, "ic_launcher_background.xml")
    with open(colors_xml_path, "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n')
        f.write('<resources>\n')
        f.write('    <color name="ic_launcher_background">#0D251D</color>\n')
        f.write('</resources>\n')
    print(f"Wrote background color to: {colors_xml_path}")

    # 2. Adaptive Icon XML in mipmap-anydpi-v26
    anydpi_dir = os.path.join(res_dir, "mipmap-anydpi-v26")
    os.makedirs(anydpi_dir, exist_ok=True)
    adaptive_xml_path = os.path.join(anydpi_dir, "ic_launcher.xml")
    with open(adaptive_xml_path, "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n')
        f.write('<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n')
        f.write('    <background android:color="@color/ic_launcher_background"/>\n')
        f.write('    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n')
        f.write('</adaptive-icon>\n')
    print(f"Wrote adaptive icon definition to: {adaptive_xml_path}")

    # Also ic_launcher_round.xml
    adaptive_round_xml = os.path.join(anydpi_dir, "ic_launcher_round.xml")
    with open(adaptive_round_xml, "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n')
        f.write('<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n')
        f.write('    <background android:color="@color/ic_launcher_background"/>\n')
        f.write('    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n')
        f.write('</adaptive-icon>\n')

    # 3. Generate icons for all mipmap densities
    for density, sizes in DENSITIES.items():
        folder = os.path.join(res_dir, f"mipmap-{density}")
        os.makedirs(folder, exist_ok=True)

        legacy_size = sizes["legacy"]
        fg_size = sizes["foreground"]

        # A. Legacy ic_launcher.png (Rounded squircle with subtle border/padding)
        legacy_canvas = Image.new("RGBA", (legacy_size, legacy_size), (0, 0, 0, 0))
        # Draw rounded rectangle background (#0D251D)
        radius = int(legacy_size * 0.22)
        bg_draw = ImageDraw.Draw(legacy_canvas)
        bg_draw.rounded_rectangle([0, 0, legacy_size - 1, legacy_size - 1], radius=radius, fill=(13, 37, 29, 255))
        
        # Scale logo into inner 80% safe zone
        inner_size = int(legacy_size * 0.82)
        inner_logo = source.resize((inner_size, inner_size), Image.Resampling.LANCZOS)
        offset = (legacy_size - inner_size) // 2
        legacy_canvas.alpha_composite(inner_logo, (offset, offset))

        legacy_path = os.path.join(folder, "ic_launcher.png")
        legacy_canvas.save(legacy_path, format="PNG")

        # B. Round ic_launcher_round.png
        round_canvas = Image.new("RGBA", (legacy_size, legacy_size), (0, 0, 0, 0))
        round_draw = ImageDraw.Draw(round_canvas)
        round_draw.ellipse([0, 0, legacy_size - 1, legacy_size - 1], fill=(13, 37, 29, 255))
        round_inner_size = int(legacy_size * 0.76)
        round_inner_logo = source.resize((round_inner_size, round_inner_size), Image.Resampling.LANCZOS)
        round_offset = (legacy_size - round_inner_size) // 2
        round_canvas.alpha_composite(round_inner_logo, (round_offset, round_offset))

        round_path = os.path.join(folder, "ic_launcher_round.png")
        round_canvas.save(round_path, format="PNG")

        # C. Adaptive Foreground ic_launcher_foreground.png (Safe zone: 66% center)
        fg_canvas = Image.new("RGBA", (fg_size, fg_size), (0, 0, 0, 0))
        fg_logo_size = int(fg_size * 0.62)
        fg_logo = source.resize((fg_logo_size, fg_logo_size), Image.Resampling.LANCZOS)
        fg_offset = (fg_size - fg_logo_size) // 2
        fg_canvas.alpha_composite(fg_logo, (fg_offset, fg_offset))

        fg_path = os.path.join(folder, "ic_launcher_foreground.png")
        fg_canvas.save(fg_path, format="PNG")

        print(f"Generated {density}: legacy {legacy_size}x{legacy_size}, fg {fg_size}x{fg_size}")

    print("\n[SUCCESS] Android launcher icon generation complete for all mipmap buckets!")

if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "assets/images/cotton_guard_logo.png"
    generate_icons(src)
