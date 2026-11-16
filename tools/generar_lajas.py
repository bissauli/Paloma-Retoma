# Texturas de lajas para los pisos del mapa V3 (veredas, plaza y peatonal): piedras irregulares
# (rectángulos y trapecios de distintos tamaños, como en las referencias) con juntas finas.
#
# Uso (Python con numpy, sin Blender ni Godot):
#   python tools/generar_lajas.py
#
# Cada imagen es de 512 x 512 px y cubre 4 x 4 m. Se repite sin cortes: el borde de la imagen es
# siempre una junta (la mitad de cada lado), así dos copias juntas forman una junta entera. Godot la
# aplica en coordenadas del mundo (Construir.material_lajas), así no hay uniones entre losas.

import os
import struct
import zlib

import numpy as np

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SALIDA = os.path.join(RAIZ, "modelos", "ciudad", "texturas")
N = 512            # píxeles por lado (4 m: 128 px por metro)


def hex_rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def lajas(seed, tonos, junta, tam_min, tam_max, ancho_junta=3.0):
    rng = np.random.default_rng(seed)
    Y, X = np.mgrid[0:N, 0:N].astype(np.float32) + 0.5
    piedra = np.zeros((N, N), np.int32)
    # Distancia de cada píxel a la junta más cercana (empieza con el borde de la imagen)
    dist = np.minimum(np.minimum(X, N - X), np.minimum(Y, N - Y))
    cuenta = [0]

    def rec(mask, x0, y0, x1, y1, prof):
        w, h = x1 - x0, y1 - y0
        grande = max(w, h)
        if prof > 14 or grande < tam_min * 1.5 or (grande < tam_max and rng.random() < 0.45):
            piedra[mask] = cuenta[0]
            cuenta[0] += 1
            return
        inc = rng.uniform(-0.28, 0.28) if rng.random() < 0.4 else 0.0
        if w >= h:   # corte casi vertical
            c = x0 + w * rng.uniform(0.32, 0.68)
            m = (y0 + y1) / 2
            d = (X - c - (Y - m) * inc) / np.sqrt(1 + inc * inc)
            lado = d > 0
            dist[mask] = np.minimum(dist[mask], np.abs(d[mask]))
            e = abs(inc) * h / 2
            rec(mask & ~lado, x0, y0, c + e, y1, prof + 1)
            rec(mask & lado, c - e, y0, x1, y1, prof + 1)
        else:        # corte casi horizontal
            c = y0 + h * rng.uniform(0.32, 0.68)
            m = (x0 + x1) / 2
            d = (Y - c - (X - m) * inc) / np.sqrt(1 + inc * inc)
            lado = d > 0
            dist[mask] = np.minimum(dist[mask], np.abs(d[mask]))
            e = abs(inc) * w / 2
            rec(mask & ~lado, x0, y0, x1, c + e, prof + 1)
            rec(mask & lado, x0, c - e, x1, y1, prof + 1)

    rec(np.ones((N, N), bool), 0.0, 0.0, float(N), float(N), 0)
    # Color de cada piedra: un tono de la lista con una variación chica
    base = np.array([hex_rgb(tonos[rng.integers(len(tonos))]) * rng.uniform(0.96, 1.04) for _ in range(cuenta[0])])
    img = base[piedra]
    # Grano fino y un leve degradé por piedra (no se ven planas)
    img *= (1.0 + rng.normal(0.0, 0.012, (N, N, 1))).astype(np.float32)
    # Borde hundido junto a la junta y la junta
    borde = np.clip((dist - ancho_junta / 2) / 3.0, 0.0, 1.0)[..., None]
    img *= 0.93 + 0.07 * borde
    j = hex_rgb(junta)
    en_junta = np.clip((ancho_junta / 2 + 0.7 - dist) / 1.4, 0.0, 1.0)[..., None]
    img = img * (1 - en_junta) + j * en_junta
    return np.clip(img, 0, 255).astype(np.uint8)


def png(ruta, rgb):
    h, w, _ = rgb.shape
    crudo = b"".join(b"\x00" + rgb[y].tobytes() for y in range(h))

    def bloque(tipo, datos):
        return struct.pack(">I", len(datos)) + tipo + datos + struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF)

    with open(ruta, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + bloque(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) +
                bloque(b"IDAT", zlib.compress(crudo, 9)) + bloque(b"IEND", b""))


IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
mipmaps/generate=true
mipmaps/limit=-1
detect_3d/compress_to=0
"""

TEXTURAS = {
    # Vereda: lajas claras beige y grises (las de las referencias)
    "lajas_vereda": (11, ["dcd5c2", "d4ccb7", "e1d9c6", "cfc8b4", "e3d8bd", "cbc3ae"], "a8a08c", 44, 120),
    # Plaza: piedras más grandes y grises
    "lajas_plaza": (12, ["d2cfc7", "cac6bd", "d9d5cc", "c3bfb6", "cfcbc0"], "9d988e", 56, 150),
    # Peatonal: lajas rojizas
    "lajas_peatonal": (13, ["d9ac90", "d0a286", "deb59b", "c99b80", "d6a68a"], "a4785f", 40, 110),
}


if __name__ == "__main__":
    os.makedirs(SALIDA, exist_ok=True)
    for nombre, (seed, tonos, junta, tmin, tmax) in TEXTURAS.items():
        ruta = os.path.join(SALIDA, nombre + ".png")
        png(ruta, lajas(seed, tonos, junta, tmin, tmax))
        imp = ruta + ".import"
        if not os.path.exists(imp):
            with open(imp, "w", encoding="utf-8") as f:
                f.write(IMPORT)
        print(ruta)
