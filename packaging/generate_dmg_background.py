#!/usr/bin/env python3
"""Generate the DMG Finder-window background image (packaging/dmg-background.png).

Style matches the app icon: deep navy -> violet -> magenta diagonal gradient,
with the app name and a "drag to install" hint. Window size must match the
--window-size passed to create-dmg (default below: 660x400 content area).
"""

from PIL import Image, ImageDraw, ImageFont
import os

WIDTH, HEIGHT = 660, 400
OUTPUT = os.path.join(os.path.dirname(__file__), "dmg-background.png")


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size, stops):
    """Diagonal 3-stop gradient: (pos, color) list."""
    w, h = size
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x / w + y / h) / 2
            for i in range(len(stops) - 1):
                p0, c0 = stops[i]
                p1, c1 = stops[i + 1]
                if p0 <= t <= p1:
                    f = 0 if p1 == p0 else (t - p0) / (p1 - p0)
                    px[x, y] = lerp(c0, c1, f)
                    break
            else:
                px[x, y] = stops[-1][1]
    return img


def load_font(size, bold=True):
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    img = gradient(
        (WIDTH, HEIGHT),
        [
            (0.00, (16, 24, 56)),    # deep navy
            (0.55, (60, 40, 120)),   # violet
            (1.00, (150, 45, 110)),  # magenta
        ],
    )
    draw = ImageDraw.Draw(img)

    # Subtle vignette: darken edges
    vignette = Image.new("L", (WIDTH, HEIGHT), 0)
    vd = ImageDraw.Draw(vignette)
    vd.ellipse((-WIDTH * 0.3, -HEIGHT * 0.3, WIDTH * 1.3, HEIGHT * 1.3), fill=90)
    img = Image.composite(
        img,
        Image.new("RGB", (WIDTH, HEIGHT), (6, 8, 20)),
        vignette,
    )
    draw = ImageDraw.Draw(img)

    # Title
    title = load_font(34, bold=True)
    draw.text((WIDTH / 2, 62), "OpenDevUtils", font=title, fill=(255, 255, 255), anchor="mm")

    # Hint line under the icons area
    hint = load_font(16, bold=False)
    draw.text((WIDTH / 2, HEIGHT - 46), "Drag to the Applications folder to install",
              font=hint, fill=(200, 205, 235), anchor="mm")

    # Thin separator under title
    draw.line((WIDTH / 2 - 90, 92, WIDTH / 2 + 90, 92), fill=(255, 255, 255, 60), width=1)

    img.save(OUTPUT)
    print(f"Wrote {OUTPUT} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()
