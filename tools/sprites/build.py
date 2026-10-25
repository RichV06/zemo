#!/usr/bin/env python3
"""Genera la hoja de sprites y los iconos de Zemo en Assets/.

    uv run --with pillow python tools/sprites/build.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

import zemo_sprites as z

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Assets" / "sprites"
OUT.mkdir(parents=True, exist_ok=True)

rows = list(z.STATES.items())
cols = max(len(frames) for _, frames in rows)
sheet = Image.new("RGBA", (cols * z.W, len(rows) * z.W), (0, 0, 0, 0))
meta = {"frameSize": z.W, "states": {}}
for r, (name, frames) in enumerate(rows):
    for i, kwargs in enumerate(frames):
        sheet.paste(z.bust(**kwargs), (i * z.W, r * z.W))
    meta["states"][name] = {"row": r, "frames": len(frames)}
sheet.save(OUT / "zemo-sheet.png")
(OUT / "frames.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2))

# barra de menú: 18 px (@1x) y 36 px (@2x, escalado entero sin interpolar)
icon = z.menubar_icon()
icon.save(OUT / "menubar.png")
icon.resize((36, 36), Image.NEAREST).save(OUT / "menubar@2x.png")

# icono de la app: busto a x12 centrado sobre fondo azul noche
canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
ImageDraw.Draw(canvas).rounded_rectangle([40, 40, 983, 983], radius=190, fill="#13171B")
canvas.alpha_composite(z.bust().resize((768, 768), Image.NEAREST), (128, 150))
canvas.save(ROOT / "Assets" / "icon-1024.png")

# vista previa para revisión humana (no la usa la app)
scale = 4
preview = Image.new("RGBA", (cols * z.W * scale, len(rows) * z.W * scale), "#13171B")
preview.alpha_composite(sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST))
preview.save(ROOT / "tools" / "sprites" / "preview.png")
print(f"{len(rows)} estados, hoja {sheet.size}, salida en {OUT}")
