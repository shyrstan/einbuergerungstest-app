"""Draws the launcher icon of the French app (same layout as the German one:
a checklist card with a flag band on a navy background)."""
from PIL import Image, ImageDraw

NAVY = (31, 58, 95, 255)
BLUE, WHITE, RED = (0, 35, 149, 255), (255, 255, 255, 255), (237, 41, 57, 255)
LINE, DONE, TODO = (205, 212, 222, 255), (31, 58, 95, 255), (205, 212, 222, 255)


def card(draw, x0, y0, w, h):
    r = int(w * 0.09)
    draw.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=r, fill=WHITE)
    band = int(h * 0.30)
    # flag band: three vertical stripes, clipped to the rounded top
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=r, fill=255)
    flag = Image.new('RGBA', (w, band), WHITE)
    fd = ImageDraw.Draw(flag)
    fd.rectangle([0, 0, w // 3, band], fill=BLUE)
    fd.rectangle([2 * w // 3, 0, w, band], fill=RED)
    draw._image.paste(flag, (x0, y0), mask.crop((0, 0, w, band)))
    draw.line([x0 + w // 3, y0 + band, x0 + 2 * w // 3, y0 + band], fill=LINE, width=max(2, w // 120))
    rows = [0.47, 0.66, 0.85]
    for i, fy in enumerate(rows):
        cy = y0 + int(h * fy)
        cr = int(w * 0.075)
        cx = x0 + int(w * 0.20)
        draw.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=DONE if i < 2 else TODO)
        if i < 2:
            s = cr / 22
            pts = [(cx - 11 * s, cy + 1 * s), (cx - 3 * s, cy + 9 * s), (cx + 12 * s, cy - 8 * s)]
            draw.line(pts, fill=WHITE, width=max(3, int(5 * s)), joint='curve')
        lx0 = x0 + int(w * 0.33); lx1 = x0 + int(w * 0.88); lh = int(h * 0.055)
        draw.rounded_rectangle([lx0, cy - lh // 2, lx1, cy + lh // 2], radius=lh // 2, fill=LINE)


def main(out_dir):
    S = 1024
    full = Image.new('RGBA', (S, S), NAVY)
    card(ImageDraw.Draw(full), 230, 190, 565, 685)
    full.save(f'{out_dir}/icon.png')
    fg = Image.new('RGBA', (S, S), (0, 0, 0, 0))  # adaptive foreground: inside the 66% safe zone
    card(ImageDraw.Draw(fg), 330, 300, 365, 442)
    fg.save(f'{out_dir}/icon_fg.png')


if __name__ == '__main__':
    import sys
    main(sys.argv[1] if len(sys.argv) > 1 else 'assets/icon/fr')
