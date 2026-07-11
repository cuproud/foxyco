"""Generate a clean circular floating-bubble asset from the fox art.

The overlay bubble was showing a box-in-a-box: the square launcher image sitting
inside the widget's own bordered circle. This bakes the fox scene into a single
circular PNG with TRANSPARENT corners, so the floating button is just the fox —
no nested square, no ring. The widget then draws it with only a soft shadow.
"""
from PIL import Image, ImageDraw

SRC = "assets/branding/foxyco_icon_car_a.png"
OUT = "assets/branding/foxyco_bubble.png"

src = Image.open(SRC).convert("RGBA")

# Same head-centered crop we use for the launcher, so bubble == app identity.
cx, cy, half = 627, 400, 360
crop = src.crop((cx - half, cy - half, cx + half, cy + half))

S = 512
crop = crop.resize((S, S), Image.LANCZOS)

# Circular alpha mask (supersampled for a smooth edge), transparent outside.
SS = 4
big = Image.new("L", (S * SS, S * SS), 0)
ImageDraw.Draw(big).ellipse((0, 0, S * SS, S * SS), fill=255)
mask = big.resize((S, S), Image.LANCZOS)

out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
out.paste(crop, (0, 0), mask)
out.save(OUT)
print("wrote", OUT, out.size)
