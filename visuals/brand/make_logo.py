"""Hand-authored pixel-art /\\FAKEMC wordmark.

The source logo is a dashed *outline* face with a heavy italic slant. Downsampling
it to anything that fits a 480x270 screen destroys it: the outline strokes go
sub-pixel and the slanted letters merge into one blob. So the wordmark is redrawn
here as solid pixel letterforms at the target size, sheared to match the original
lean, and coloured into the reef teal ramp (docs/visual-bible.md 2.2 has no red
family). This is the same thing a pixel artist would do by hand.
"""
import numpy as np
from PIL import Image, ImageFilter

H = 10
SLANT = 0.45

GLYPHS = {
    "F": ["111111", "111111", "110000", "110000", "111110",
          "111110", "110000", "110000", "110000", "110000"],
    "A": ["011110", "111111", "110011", "110011", "111111",
          "111111", "110011", "110011", "110011", "110011"],
    "K": ["110011", "110011", "110110", "111100", "111000",
          "111100", "110110", "110011", "110011", "110011"],
    "E": ["111111", "111111", "110000", "110000", "111110",
          "111110", "110000", "110000", "111111", "111111"],
    "M": ["1100011", "1110111", "1111111", "1111111", "1101011",
          "1100011", "1100011", "1100011", "1100011", "1100011"],
    "C": ["011110", "111111", "110011", "110000", "110000",
          "110000", "110000", "110011", "111111", "011110"],
    "/": ["11", "11", "11", "11", "11", "11", "11", "11", "11", "11"],
}

LAYOUT = [("/", 2), ("/", 3), ("F", 1), ("A", 1), ("K", 1), ("E", 1), ("M", 1), ("C", 0)]

# Lay the word out upright first, then shear whole rows so the lean lands on
# exact pixel boundaries rather than being interpolated.
cols = sum(len(GLYPHS[ch][0]) + gap for ch, gap in LAYOUT)
shear = int(SLANT * (H - 1)) + 1
upright = np.zeros((H, cols), bool)
x = 0
for ch, gap in LAYOUT:
    bitmap = GLYPHS[ch]
    for y, row in enumerate(bitmap):
        for dx, c in enumerate(row):
            if c == "1":
                upright[y, x + dx] = True
    x += len(bitmap[0]) + gap

body = np.zeros((H, cols + shear), bool)
for y in range(H):
    off = int(round(SLANT * (H - 1 - y)))
    body[y, off:off + cols] = upright[y]

RIM = (0x14, 0x3C, 0x68)
BODY = (0x4F, 0xC3, 0xD6)
HI = (0xCF, 0xF4, 0xFA)


def render(scale: int) -> Image.Image:
    b = np.kron(body, np.ones((scale, scale), bool))
    h, w = b.shape
    # One pixel of dark rim all round keeps the mark readable over the bright
    # water in the background, where a bare teal would disappear.
    rim = np.asarray(
        Image.fromarray((b * 255).astype(np.uint8), "L").filter(ImageFilter.MaxFilter(3))
    ) > 127
    top = b & ~np.roll(b, scale, axis=0)
    out = np.zeros((h + 2, w + 2, 4), np.uint8)
    for band, col in ((rim, RIM), (b, BODY), (top, HI)):
        padded = np.zeros((h + 2, w + 2), bool)
        padded[1:h + 1, 1:w + 1] = band
        out[padded, 0:3] = col
        out[padded, 3] = 255
    return Image.fromarray(out, "RGBA")


if __name__ == "__main__":
    import sys
    dest = sys.argv[1] if len(sys.argv) > 1 else "."
    img = render(1)
    img.save(f"{dest}/logo_fakemc.png")
    print("logo_fakemc.png", img.size)
