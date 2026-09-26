"""Pack de íconos minimalistas "selva oscura" (SVG + PNG 512px + ICO para Windows).

Uso: python3 generate_icons.py   (requiere: pip install cairosvg pillow)
Salida: svg/*.svg, png/*.png e ico/*.ico
"""
import os

BG = "#0e1f19"       # verde casi negro
BG2 = "#132a22"      # degradado sutil
BORDER = "#24463a"
FG = "#a9d3b8"       # verde salvia claro
ACCENT = "#5fbf8f"   # verde hoja

def burst(cx, cy, r_long, r_short, n, width=18):
    """Estrella de rayos alternados (motivo 'chispa')."""
    lines = "".join(
        f'<line x1="{cx}" y1="{cy}" x2="{cx}" y2="{cy - (r_long if i % 2 == 0 else r_short)}" '
        f'transform="rotate({i * 360 / n} {cx} {cy})"/>'
        for i in range(n))
    return f'<g stroke="{ACCENT}" stroke-width="{width}">{lines}</g>'


# Cada glifo se dibuja en un área de 512x512, trazo de línea fino y redondeado.
GLYPHS = {
    "claude": burst(256, 256, 106, 76, 12),
    "claude-code": '<path d="M150 190 L220 256 L150 322"/><line x1="250" y1="322" x2="362" y2="322" stroke="' + ACCENT + '"/>',
    "folder-claude": '<path d="M130 180 h80 l28 28 h144 a16 16 0 0 1 16 16 v124 a16 16 0 0 1 -16 16 h-236 a16 16 0 0 1 -16 -16 v-152 a16 16 0 0 1 16 -16z"/>'
                     + burst(256, 290, 36, 26, 8, 14),
    "phone": '<path d="M180 150 l40 -6 30 70 -30 22 a150 150 0 0 0 52 52 l22 -30 70 30 -6 40 a24 24 0 0 1 -24 20 A200 200 0 0 1 160 174 a24 24 0 0 1 20 -24z"/>',
    "messages": '<path d="M150 180 a26 26 0 0 1 26 -26 h160 a26 26 0 0 1 26 26 v110 a26 26 0 0 1 -26 26 h-110 l-56 44 v-44 a26 26 0 0 1 -20 -26z"/>',
    "chat": '<path d="M256 150 a106 100 0 1 1 -58 184 l-50 16 16 -46 A106 100 0 0 1 256 150z"/><path d="M226 222 q0 40 60 68" stroke="' + ACCENT + '"/>',
    "camera": '<rect x="140" y="190" width="232" height="160" rx="28"/><path d="M210 190 l18 -30 h56 l18 30"/><circle cx="256" cy="270" r="44" stroke="' + ACCENT + '"/>',
    "gallery": '<rect x="146" y="160" width="220" height="192" rx="28"/><path d="M146 318 l70 -70 60 60 34 -34 56 56"/><circle cx="306" cy="214" r="18" stroke="' + ACCENT + '"/>',
    "browser": '<circle cx="256" cy="256" r="106"/><ellipse cx="256" cy="256" rx="46" ry="106"/><line x1="150" y1="256" x2="362" y2="256" stroke="' + ACCENT + '"/>',
    "settings": '<circle cx="256" cy="256" r="40" stroke="' + ACCENT + '"/>' + "".join(
        f'<line x1="256" y1="160" x2="256" y2="186" transform="rotate({i * 45} 256 256)"/>' for i in range(8))
        + '<circle cx="256" cy="256" r="72"/>',
    "music": '<path d="M226 330 V170 l110 -20 v150"/><circle cx="200" cy="330" r="26" stroke="' + ACCENT + '"/><circle cx="310" cy="300" r="26" stroke="' + ACCENT + '"/>',
    "maps": '<path d="M256 364 C200 300 170 256 170 220 a86 86 0 0 1 172 0 c0 36 -30 80 -86 144z"/><circle cx="256" cy="220" r="28" stroke="' + ACCENT + '"/>',
    "mail": '<rect x="140" y="176" width="232" height="164" rx="24"/><path d="M146 188 l110 84 110 -84" stroke="' + ACCENT + '"/>',
    "calendar": '<rect x="148" y="170" width="216" height="190" rx="26"/><line x1="148" y1="222" x2="364" y2="222"/><line x1="206" y1="150" x2="206" y2="190"/><line x1="306" y1="150" x2="306" y2="190"/><circle cx="256" cy="290" r="10" fill="' + ACCENT + '" stroke="none"/>',
    "clock": '<circle cx="256" cy="256" r="106"/><path d="M256 190 V256 l44 30" stroke="' + ACCENT + '"/>',
    "files": '<path d="M136 190 a18 18 0 0 1 18 -18 h66 l26 26 h112 a18 18 0 0 1 18 18 v124 a18 18 0 0 1 -18 18 h-204 a18 18 0 0 1 -18 -18z"/><line x1="136" y1="236" x2="376" y2="236" stroke="' + ACCENT + '"/>',
    "notes": '<rect x="170" y="150" width="172" height="212" rx="22"/><line x1="206" y1="206" x2="306" y2="206"/><line x1="206" y1="250" x2="306" y2="250"/><line x1="206" y1="294" x2="268" y2="294" stroke="' + ACCENT + '"/>',
    "leaf": '<path d="M160 352 C160 220 250 160 356 156 C352 262 292 352 160 352z"/><path d="M168 344 L300 212" stroke="' + ACCENT + '"/>',
}


def icon_svg(glyph):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{BG2}"/>
      <stop offset="1" stop-color="{BG}"/>
    </linearGradient>
  </defs>
  <rect x="8" y="8" width="496" height="496" rx="140" fill="url(#g)" stroke="{BORDER}" stroke-width="4"/>
  <g fill="none" stroke="{FG}" stroke-width="18" stroke-linecap="round" stroke-linejoin="round">
    {glyph}
  </g>
</svg>
'''


if __name__ == "__main__":
    import cairosvg
    from PIL import Image

    here = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(os.path.join(here, "svg"), exist_ok=True)
    os.makedirs(os.path.join(here, "png"), exist_ok=True)
    os.makedirs(os.path.join(here, "ico"), exist_ok=True)
    for name, glyph in GLYPHS.items():
        svg = icon_svg(glyph)
        with open(os.path.join(here, "svg", f"{name}.svg"), "w") as f:
            f.write(svg)
        cairosvg.svg2png(bytestring=svg.encode(), write_to=os.path.join(here, "png", f"{name}.png"),
                         output_width=512, output_height=512)
        Image.open(os.path.join(here, "png", f"{name}.png")).save(
            os.path.join(here, "ico", f"{name}.ico"),
            sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
        print("ok", name)
