#!/usr/bin/env python3
"""Draws the PawPass app icon and store graphics, and writes them into the Android and iOS projects.

    python3 tools/make_store_icons.py

Needs Pillow. Safe to run again: it only overwrites the icon files. The mark is the same paw as the in-app icon
(apps/mobile/lib/ui/paw_icon.dart), filled, white on the primary teal.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
MOBILE = ROOT / "apps" / "mobile"
STORE = ROOT / "store"
TEAL = (14, 107, 99)       # #0E6B63 primary
GROUND = (255, 248, 241)   # #FFF8F1
INK = (31, 26, 23)
SS = 4                     # supersampling


def bezier(p0, p1, p2, p3, n=24):
    pts = []
    for i in range(n + 1):
        t = i / n
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t ** 2, t ** 3
        pts.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return pts


# The paw from paw_icon.dart, in its 24 by 24 box.
PAD_PATH = (
    bezier((12, 12), (9, 12), (7, 15.5), (7, 17.5))
    + bezier((7, 17.5), (7, 19.5), (9, 20), (12, 20))
    + bezier((12, 20), (15, 20), (17, 19.5), (17, 17.5))
    + bezier((17, 17.5), (17, 15.5), (15, 12), (12, 12))
)
TOES = [(7, 10), (17, 10), (10, 6), (14, 6)]


def paw(size, color, bg=None, scale=0.62, radius=0.0):
    """A square image with the paw centred. `scale` is how much of the square the 24 unit box fills."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if bg is not None:
        if radius:
            d.rounded_rectangle((0, 0, s, s), radius=int(s * radius), fill=bg)
        else:
            d.rectangle((0, 0, s, s), fill=bg)
    k = s * scale / 24
    ox = oy = (s - 24 * k) / 2
    # The box is 24 wide but the paw only spans x 5 to 19 and y 4 to 20: centre what is drawn.
    ox -= (12 - 12) * k
    oy -= (12 - 12) * k

    def pt(x, y):
        return (ox + x * k, oy + y * k)

    for cx, cy in TOES:
        x, y = pt(cx, cy)
        r = 2.0 * k
        d.ellipse((x - r, y - r, x + r, y + r), fill=color)
    d.polygon([pt(x, y) for x, y in PAD_PATH], fill=color)
    return img.resize((size, size), Image.LANCZOS)


def app_icon(size, flat=False):
    """Teal square, white paw. iOS wants it square with no transparency; Android masks it itself."""
    img = paw(size, (255, 255, 255), bg=TEAL, scale=0.66)
    return img.convert("RGB")


def save(img, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print("wrote", path.relative_to(ROOT))


# --- Android launcher icons (round corners are applied by the launcher mask on 8+; keep a soft corner for older)
for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    save(app_icon(px), MOBILE / "android/app/src/main/res" / f"mipmap-{folder}" / "ic_launcher.png")

# --- iOS: every size in the icon set
ios = MOBILE / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
sizes = {
    "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40, "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29, "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80, "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120, "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76, "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167, "Icon-App-1024x1024@1x.png": 1024,
}
for name, px in sizes.items():
    save(app_icon(px), ios / name)

# --- Store graphics
save(app_icon(1024), STORE / "app-icon-1024.png")
save(app_icon(512), STORE / "play-icon-512.png")


def font(name, size):
    return ImageFont.truetype(str(MOBILE / "assets/fonts" / name), size)


def feature_graphic():
    w, h = 1024, 500
    img = Image.new("RGB", (w, h), TEAL)
    d = ImageDraw.Draw(img)
    mark = paw(300, (255, 255, 255), bg=None, scale=0.9)
    # a soft circle behind the mark
    d.ellipse((60, 100, 360, 400), fill=(11, 86, 80))
    img.paste(mark, (60, 100), mark)
    d.text((410, 150), "PawPass", font=font("BricolageGrotesque-Bold.ttf", 96), fill=(255, 255, 255))
    d.text((414, 270), "Your pet's health, care and", font=font("PlusJakartaSans-SemiBold.ttf", 34), fill=(227, 241, 238))
    d.text((414, 316), "safety, in one passport.", font=font("PlusJakartaSans-SemiBold.ttf", 34), fill=(227, 241, 238))
    return img


save(feature_graphic(), STORE / "play-feature-graphic-1024x500.png")
