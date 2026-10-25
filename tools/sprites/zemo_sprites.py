"""Zemo: busto 64x64 en pixel art, dibujado por primitivas. Luz desde arriba-izquierda.

Sin antialiasing a propósito: cada pixel es una decisión. Paleta cerrada (ver PALETTE).
"""
import random

from PIL import Image, ImageDraw

W = 64

PALETTE = dict(
    ink="#0B0E12", glass="#14202B", glass2="#1B3040", hl="#B7D9E0", hl2="#6FAAB8",
    f1="#262F3C", f2="#3A485A", f3="#566A82", f4="#8196AE",
    t1="#7A431F", t2="#A96B35", t3="#D29758", t4="#EFC48A",
    bone="#E2DAC6", bone2="#B5AC95", bone3="#857E6B", steel="#39424F", steel2="#252C36",
    orange="#C9854A", amber="#E8A93A", cyan="#58C9CF", eye="#D98324", white="#F4F1E8",
)


def bust(blink=False, talk=0, hud=1, tint=None, hudc=None, extra=None, ant_on=True, eyes=None):
    c = dict(PALETTE)
    if tint:
        c["glass2"] = tint
    hc = hudc or c["cyan"]
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # casco: cúpula de vidrio
    d.ellipse([4, 3, 59, 56], fill=c["ink"])
    d.ellipse([5, 4, 58, 55], fill=c["glass"])
    d.ellipse([9, 8, 54, 52], fill=c["glass2"])

    # orejas erguidas
    d.polygon([(15, 26), (14, 6), (29, 19)], fill=c["f2"])
    d.polygon([(17, 22), (16, 10), (25, 19)], fill=c["t2"])
    d.line([(15, 8), (15, 24)], fill=c["f3"])
    d.polygon([(31, 17), (41, 4), (45, 23)], fill=c["f1"])
    d.polygon([(34, 17), (41, 9), (43, 20)], fill=c["t1"])
    d.line([(41, 5), (44, 20)], fill=c["f2"])

    # cabeza: gris azulado de heeler, luz arriba-izquierda
    d.ellipse([15, 16, 43, 44], fill=c["f3"])
    d.ellipse([15, 16, 38, 38], fill=c["f3"])
    d.pieslice([15, 16, 43, 44], 300, 90, fill=c["f2"])
    d.arc([17, 18, 41, 42], 200, 290, fill=c["f4"])
    rng = random.Random(7)  # moteado reproducible
    for _ in range(34):
        x, y = rng.randint(17, 31), rng.randint(18, 40)
        d.point((x, y), fill=c["f4"] if rng.random() < 0.5 else c["f2"])

    # hocico corto
    d.ellipse([32, 28, 49, 43], fill=c["t3"])
    d.ellipse([35, 36, 48, 45], fill=c["bone"])
    d.pieslice([32, 28, 49, 43], 20, 150, fill=c["t2"])
    d.polygon([(30, 25), (42, 26), (47, 30), (34, 33)], fill=c["f3"])
    d.line([(31, 26), (42, 27)], fill=c["f4"])
    d.polygon([(22, 32), (33, 30), (36, 40), (26, 41)], fill=c["t2"])
    d.line([(23, 33), (31, 31)], fill=c["t3"])

    # nariz
    d.rectangle([46, 30, 50, 33], fill=c["ink"])
    d.rectangle([47, 29, 49, 29], fill=c["ink"])
    d.rectangle([47, 34, 49, 34], fill=c["ink"])
    d.point((47, 30), fill=c["f4"])

    # boca: comisura apenas arriba (ironía sobria)
    my = 39 + (1 if talk else 0)
    d.line([(47, 36), (45, 38), (41, my), (38, my - 1)], fill=c["t1"])
    if talk:
        d.rectangle([40, 40, 45, 41 + talk], fill=c["ink"])
        d.rectangle([41, 40, 44, 40], fill=c["bone"])

    # ceja canela + ojo
    d.rectangle([31, 22, 35, 23], fill=c["t2"])
    if eyes == "happy":
        d.arc([31, 24, 37, 30], 200, 340, fill=c["ink"])
        d.line([(31, 26), (31, 27)], fill=c["ink"]); d.line([(37, 26), (37, 27)], fill=c["ink"])
    elif blink:
        d.line([(31, 26), (37, 26)], fill=c["ink"])
    else:
        d.rectangle([31, 25, 37, 28], fill=c["ink"])
        d.rectangle([32, 25, 36, 27], fill=c["eye"])
        d.rectangle([34, 25, 35, 27], fill=c["ink"])
        d.point((33, 25), fill=c["white"])
        top = 22 if eyes == "focus" else 23
        d.line([(30, 24), (38, top)], fill=c["ink"])  # párpado escéptico

    # cuello de pelaje
    d.polygon([(18, 40), (36, 42), (40, 50), (14, 50)], fill=c["f2"])
    for p in [(20, 44), (24, 46), (28, 44), (32, 47), (36, 46), (22, 48), (30, 49), (26, 42)]:
        d.point(p, fill=c["f3"])

    # anillo del casco
    d.ellipse([6, 44, 57, 62], fill=c["ink"])
    d.ellipse([7, 45, 56, 61], fill=c["bone2"])
    d.ellipse([7, 45, 56, 56], fill=c["bone"])
    d.arc([9, 46, 54, 58], 180, 360, fill=c["white"])
    d.arc([7, 45, 56, 61], 20, 160, fill=c["bone3"])
    d.ellipse([16, 49, 47, 58], fill=c["steel"])

    # traje
    d.polygon([(2, 63), (8, 53), (56, 53), (62, 63)], fill=c["bone"])
    d.polygon([(40, 53), (56, 53), (62, 63), (44, 63)], fill=c["bone2"])
    d.line([(8, 53), (56, 53)], fill=c["ink"])
    for x in (11, 20, 43, 52):
        d.rectangle([x, 51, x + 1, 52], fill=c["orange"])
    d.rectangle([22, 56, 42, 63], fill=c["steel2"])
    d.rectangle([23, 57, 41, 63], fill=c["steel"])
    d.rectangle([25, 58, 28, 59], fill=c["amber"] if hud >= 1 else c["steel2"])
    d.rectangle([30, 58, 33, 59], fill=c["cyan"] if hud >= 2 else c["steel2"])
    d.rectangle([35, 58, 39, 59], fill=c["orange"] if hud >= 3 else c["steel2"])
    d.line([(25, 61), (39, 61)], fill=c["bone3"])
    d.line([(14, 54), (18, 63)], fill=c["orange"])
    d.line([(48, 54), (45, 63)], fill=c["orange"])

    # reflejos del vidrio y HUD (discretos)
    d.arc([6, 5, 57, 54], 200, 262, fill=c["hl"])
    d.arc([7, 6, 56, 53], 205, 245, fill=c["hl"])
    d.arc([8, 7, 55, 52], 265, 290, fill=c["hl2"])
    d.line([(12, 14), (15, 10)], fill=c["hl"])
    d.line([(46, 8), (51, 8)], fill=hc)
    d.line([(51, 8), (51, 11)], fill=hc)
    for i, x in enumerate((46, 49, 52)):
        d.point((x, 13), fill=hc if i < hud + 1 else c["steel"])

    # antena corta
    d.line([(10, 10), (7, 3)], fill=c["bone2"])
    d.rectangle([6, 2, 8, 3], fill=c["amber"] if ant_on else c["bone3"])

    if extra == "listen":
        for r, col in ((3, c["cyan"]), (6, c["hl2"])):
            d.arc([57 - r, 30 - r * 2, 57 + r * 2, 30 + r * 2], 300, 60, fill=col)
    elif extra == "alert":
        d.rectangle([48, 15, 49, 19], fill=hc)
        d.rectangle([48, 21, 49, 22], fill=hc)
    elif extra == "call":
        d.arc([2, 0, 13, 9], 180, 270, fill=c["amber"])
        d.arc([-1, -3, 16, 12], 180, 270, fill=c["orange"])
    elif extra == "push":
        for x in (44, 49):  # chevrones ">>" hacia adelante
            d.line([(x, 15), (x + 2, 17)], fill=hc)
            d.line([(x + 2, 17), (x, 19)], fill=hc)
    elif extra == "celebrate":
        for p in [(48, 14), (53, 18), (11, 18)]:
            d.point(p, fill=c["amber"])
            d.point((p[0] - 1, p[1]), fill=c["amber"]); d.point((p[0] + 1, p[1]), fill=c["amber"])
            d.point((p[0], p[1] - 1), fill=c["amber"]); d.point((p[0], p[1] + 1), fill=c["amber"])

    # scanlines CRT: filas pares sobre el vidrio
    px = img.load()
    glass_rgb = {tuple(int(c[k][i:i + 2], 16) for i in (1, 3, 5)) for k in ("glass", "glass2")}
    for y in range(6, 50, 2):
        for x in range(W):
            if px[x, y][:3] in glass_rgb:
                r, g, b, a = px[x, y]
                px[x, y] = (int(r * 0.8), int(g * 0.8), int(b * 0.8), 255)
    return img


LISTEN = "#0F3A48"
CALL = "#2A2410"
ALERT = "#3A2A10"

STATES = {
    "reposo":   [dict(), dict(blink=True)],
    "escucha":  [dict(tint=LISTEN, hud=2, extra="listen"), dict(tint=LISTEN, hud=2, extra="listen", blink=True)],
    "pensando": [dict(hud=0), dict(hud=1), dict(hud=2)],
    "hablando": [dict(talk=0), dict(talk=1), dict(talk=2)],
    "llamada":  [dict(extra="call", hud=2, tint=CALL, hudc="#E8A93A"),
                 dict(extra="call", hud=2, tint=CALL, hudc="#E8A93A", ant_on=False)],
    "alerta":   [dict(tint=ALERT, hudc="#E8A93A", extra="alert", hud=2),
                 dict(tint="#2A2010", hudc="#E8A93A", extra="alert", hud=2)],
    "celebra":  [dict(eyes="happy", extra="celebrate", hud=3), dict(eyes="happy", hud=3)],
    "empuja":   [dict(eyes="focus", extra="push", hud=2, hudc="#E8A93A"),
                 dict(eyes="focus", hud=2, hudc="#E8A93A")],
}


def menubar_icon():
    """Icono 18x18 de plantilla (solo canal alfa), cabeza de Zemo dentro del casco."""
    img = Image.new("RGBA", (18, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    k = (0, 0, 0, 255)
    d.ellipse([0, 1, 17, 17], outline=k)
    d.polygon([(4, 9), (4, 3), (8, 7)], fill=k)
    d.polygon([(10, 6), (13, 3), (13, 10)], fill=k)
    d.ellipse([4, 6, 13, 14], fill=k)
    d.rectangle([12, 10, 15, 13], fill=k)
    img.putpixel((10, 9), (0, 0, 0, 0))
    img.putpixel((15, 10), (0, 0, 0, 0))
    return img
