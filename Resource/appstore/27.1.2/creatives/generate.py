#!/usr/bin/env python3
"""Compose App Store creatives from unmodified native widget captures.

Requires Pillow, numpy, and the store-screenshots skill documented in README.md.
Run with --skill-dir if the skill is installed in a different location.
"""
from pathlib import Path
import argparse
import sys
from PIL import Image, ImageDraw, ImageFont

parser = argparse.ArgumentParser()
parser.add_argument('--skill-dir', type=Path, default=Path.home() / '.codex/skills/store-screenshots')
args = parser.parse_args()
sys.path.insert(0, str(args.skill_dir / 'scripts'))
import build_tiles as tiles

ROOT = Path(__file__).resolve().parent
tiles._ACTIVE.update(display='space-grotesk', text='inter')
INK, MUTED, ACCENT = '#182329', '#607073', '#147D80'
THEME = dict(bg='#FBFAF6', bg2='#F0F6F4', background='gradient')


def text(canvas, value, xy, size, colour=INK, weight='heavy', role='display'):
    ImageDraw.Draw(canvas).text(xy, value, font=tiles.font(size, weight, role), fill=colour, anchor='lt')


def widget(canvas, filename, x, y, width, angle=0):
    source = Image.open(ROOT / 'sources' / filename).convert('RGBA')
    height = round(width * source.height / source.width)
    # One scale factor for both axes. UI content is never reconstructed.
    layer = source.resize((width, height), Image.Resampling.LANCZOS)
    mask = Image.new('L', layer.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width, height), round(height * .13), fill=255)
    layer.putalpha(mask)
    tiles.place(canvas, layer, x, y, rotate=angle, alpha=12)


def brand(canvas, x, y):
    icon = Image.open(ROOT / 'sources' / 'app-icon.png').convert('RGBA').resize((116, 116), Image.Resampling.LANCZOS)
    mask = Image.new('L', icon.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 116, 116), 28, fill=255)
    icon.putalpha(mask)
    canvas.alpha_composite(icon, (x, y))
    text(canvas, 'ScriptWidget', (x + 150, y + 20), 78, weight='demi')


def code_card(canvas, x, y, width, height):
    card = Image.new('RGBA', (width, height))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle((1, 1, width-2, height-2), 48, fill='#FFFFFF', outline='#E0E8E4', width=3)
    for i, c in enumerate(['#F2BBB1', '#EDDCAB', '#A9D5C4']):
        d.ellipse((48 + i*34, 40, 66 + i*34, 58), fill=c)
    d.text((166, 35), 'main.jsx', font=tiles.font(31, 'medium'), fill='#788588')
    mono = ImageFont.truetype('/System/Library/Fonts/Menlo.ttc', 48)
    lines = [('$render(', '#9459A5'), ('  <text font="title">', '#217F83'), ('    Hello, world', '#273E43'), ('  </text>', '#217F83'), (');', '#9459A5')]
    for i, (value, colour) in enumerate(lines):
        d.text((60, 100 + i*68), value, font=mono, fill=colour)
    tiles.place(canvas, card, x, y, alpha=9)


def header():
    canvas = tiles.make_strip((3840, 1646), 1, THEME)
    brand(canvas, 220, 230)
    text(canvas, 'Widgets,', (210, 510), 255)
    text(canvas, 'your way.', (210, 805), 255, ACCENT)
    text(canvas, 'Create with', (224, 1170), 68, MUTED, 'regular', 'text')
    text(canvas, 'JSX-style JavaScript.', (224, 1264), 68, MUTED, 'regular', 'text')
    widget(canvas, 'golden-bloom.png', 1990, 260, 585, 3)
    widget(canvas, 'orbital-resonance.png', 2725, 155, 585, -3)
    widget(canvas, 'habits.png', 2200, 930, 1140, -2)
    return canvas


def search():
    canvas = tiles.make_strip((3840, 2560), 1, THEME)
    brand(canvas, 250, 220)
    text(canvas, 'Widgets,', (240, 530), 255)
    text(canvas, 'your way.', (240, 825), 255, ACCENT)
    text(canvas, 'Create with', (254, 1170), 68, MUTED, 'regular', 'text')
    text(canvas, 'JSX-style JavaScript.', (254, 1264), 68, MUTED, 'regular', 'text')
    code_card(canvas, 250, 1530, 1460, 540)
    widget(canvas, 'golden-bloom.png', 1990, 450, 640, 3)
    widget(canvas, 'orbital-resonance.png', 2730, 720, 640, -3)
    widget(canvas, 'habits.png', 2040, 1620, 1320, -2)
    return canvas


for name, image in [('header-en.png', header()), ('search-results-en.png', search())]:
    output = ROOT / name
    image.convert('RGB').save(output, optimize=True)
    print(f'{output}: {image.width}x{image.height}, RGB')
