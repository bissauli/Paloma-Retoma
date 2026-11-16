# Paleta única de los kits de Blender (ciudad y parque). Mapa V3.
#
# Cada color es una celda de la textura con un degradé vertical (abajo oscuro, arriba claro): las
# piezas se pintan poniendo sus UV en el medio de la celda y la V según la altura. Todos los kits usan
# la misma paleta y la misma disposición de celdas, así en Godot comparten UN material (Kit lo arma a
# partir de KitDatos.PALETA) y se fusionan juntas.
#
# Celdas: 8 columnas x 16 filas (128 colores), cada una de 64 x 64 px -> imagen de 512 x 1024.
# Los primeros 64 colores conservan el orden del mapa V2 (las piezas viejas no cambian de celda); el
# mapa V3 retocó sus tonos (más saturados, como las referencias) y sumó los 64 de abajo.

import os
import numpy as np

PAL = [  # nombre, arriba, abajo (sRGB)
    # ---- 0..63: los del mapa V2 (mismo orden), con los tonos del V3
    ("pasto", "62ae4e", "3e8a40"), ("hoja", "70c656", "2f8a3a"), ("hoja_osc", "55ad4a", "246f33"),
    ("tronco", "a86a42", "6b3f27"), ("piedra", "e6e3dc", "b3b4b0"), ("piedra_osc", "b9bab4", "86888a"),
    ("agua", "a6e6ff", "4aa8e8"), ("madera", "cf8e55", "8f5530"),
    ("metal", "5a6168", "2b3035"), ("luz", "fff4b8", "ffcf5c"), ("tierra", "a0724a", "6a472c"),
    ("flor_rosa", "ff9cc8", "e0628f"), ("flor_amarilla", "ffe46b", "f2b53a"), ("jacaranda", "c6a4ff", "8159d6"),
    ("arena", "f6d7a0", "dcab6e"), ("blanco", "ffffff", "e2e4e6"),
    ("fachada_crema", "f8e6b8", "dec58e"), ("fachada_terracota", "ec9270", "c46349"),
    ("fachada_rosa", "f4aca4", "d27d77"), ("fachada_celeste", "a6d6f4", "6fa6d4"),
    ("fachada_verde", "afe0b6", "7cbb8e"), ("fachada_amarilla", "f7d578", "dcab4a"),
    ("fachada_gris", "dddbd3", "aeaca4"), ("fachada_lila", "d3bff0", "a38fd0"),
    ("ladrillo", "cd6e4b", "924631"), ("fachada_beige", "eedab4", "cbae86"), ("medianera", "d3c6ae", "9d8e78"),
    ("vidrio", "c9eefc", "71b2dc"), ("vidrio_osc", "6f97b6", "2c4358"), ("marco", "ffffff", "d6d3cc"),
    ("persiana", "e2e6e9", "a8aeb3"), ("hierro", "4a5056", "1e2125"),
    ("toldo_rojo", "ef5f50", "b73a2f"), ("toldo_verde", "58ba82", "2e7d55"), ("toldo_azul", "5a96dc", "305da0"),
    ("toldo_amarillo", "ffd256", "e09a2a"), ("toldo_naranja", "ffa25a", "d8692b"),
    ("asfalto", "80837d", "5d605b"), ("vereda", "dcd4c0", "b7ad97"), ("cordon", "eeebe4", "bdb9b0"),
    ("pizarra", "7a89a0", "4b566e"), ("cupula", "98cabd", "5e9087"), ("tejas", "df7a4e", "a8492d"),
    ("chapa", "bfc7cc", "7e878e"), ("oxido", "cf8449", "894a2b"), ("tanque", "50565c", "23272b"),
    ("plastico_rojo", "ff6455", "cd3428"), ("plastico_azul", "5aaeff", "2e6dd2"),
    ("plastico_amarillo", "ffdd57", "efa62d"), ("plastico_verde", "78e272", "39a74a"),
    ("azotea", "cf9a82", "98654f"), ("goma_azul", "6a9ada", "40639e"),
    ("perro_blanco", "fcfcf8", "d6d3cb"), ("perro_marron", "d0925a", "8c5832"), ("perro_negro", "54504d", "262220"),
    ("gato_naranja", "f5a656", "bf6a28"), ("grafiti_rosa", "ff66b8", "cf2f7d"), ("grafiti_cian", "55e6e6", "21a6b6"),
    ("grafiti_lima", "cdf460", "8cbe2c"), ("contenedor", "5fae5a", "2f6e3a"), ("buzon", "e8503f", "a5291f"),
    ("sombra", "50545d", "2a2c32"), ("naranja", "ff9145", "dd5a1d"), ("kiosco", "3a7d58", "1c4a33"),
    # ---- 64..127: nuevos del mapa V3
    # fachadas como las de las referencias (pastel saturado) y sus remates de color
    ("fachada_mostaza", "e8b55a", "c28a38"), ("fachada_salmon", "e8806e", "c05a4c"),
    ("fachada_menta", "9ed6a8", "6aa87a"), ("fachada_cielo", "8cc4ec", "5a92c4"),
    ("fachada_coral", "f39a86", "cc6a5a"), ("fachada_ocre", "d9a067", "aa7342"),
    ("remate_marron", "b25a3e", "7c3726"), ("remate_verde", "4f9a64", "2f6a42"),
    ("remate_azul", "4f7fc0", "2f5288"), ("remate_crema", "fbf1d8", "dacfae"),
    ("techo", "9c9a92", "7a7871"), ("techo_osc", "807e78", "5e5c57"),
    ("aire_ac", "e8eaea", "b9bdbf"), ("rejilla", "70767b", "3c4044"),
    ("cano", "b5bcc0", "7d858b"), ("parabolica", "f2f2ee", "c4c6c4"),
    # vehículos
    ("auto_celeste", "8fd0f2", "4c95c8"), ("auto_naranja", "ffb347", "e07a1e"),
    ("auto_amarillo", "ffe15a", "e6b31f"), ("auto_verde", "b6e08e", "7bb257"),
    ("auto_rojo", "f0645a", "b8352e"), ("auto_blanco", "f8f8f6", "cfd2d4"),
    ("auto_negro", "4a4e55", "1c1f24"), ("colectivo", "8cc55a", "4f8c35"),
    ("goma", "3a3c40", "18191b"), ("llanta", "d6dadd", "8f969c"),
    ("faro", "fffbe6", "ffe7a0"), ("luz_freno", "ff5a4a", "c02a20"),
    ("parabrisas", "8fb8d6", "34536e"), ("interior", "6a6e74", "36393e"),
    # calle y mobiliario
    ("hidrante", "f0533f", "b02c20"), ("contenedor_azul", "5a7fd0", "2f4b92"),
    ("contenedor_amarillo", "f5d14e", "d39c25"), ("tapa_contenedor", "4f5a52", "2a312c"),
    ("cartel_azul", "4a86d8", "2a569c"), ("poste", "a9b1b6", "6d757b"),
    ("semaforo", "3a3f45", "1a1d21"), ("luz_verde", "7dff8a", "2fd05a"),
    ("luz_amarilla", "ffe46a", "f2b02a"), ("luz_roja", "ff6a5a", "d8302a"),
    ("valla_roja", "f4584a", "c83226"), ("tierra_obra", "b58457", "7a5233"),
    ("cano_obra", "a9b8c0", "6f7e88"), ("sombrilla_crema", "fff3d6", "e6d2a6"),
    # plaza, parque y juegos
    ("pasto_claro", "8fd66a", "58aa4a"), ("pino", "4fae58", "1f6b38"),
    ("flor_azul", "8ec2ff", "4c80dc"), ("flor_blanca", "ffffff", "dfe3ea"),
    ("flor_naranja", "ffb060", "ec7a2a"), ("flor_violeta", "c98cf0", "8e52c8"),
    ("flor_roja", "ff6f6f", "d23a48"), ("cancha", "7e9a7c", "5a7458"),
    ("cancha_naranja", "e8945a", "b8643a"), ("piso_goma_rojo", "e2725f", "b04a3a"),
    ("lajas", "e0d6bf", "bcb096"), ("lajas_osc", "c7bba0", "a1957c"),
    # edificios especiales
    ("hospital", "fbfbf8", "dadcdc"), ("cruz_roja", "f04848", "c02626"),
    ("policia", "4f86c8", "2b5590"), ("policia_claro", "a8d0f2", "73a0d0"),
    ("letrero", "a8553c", "74351f"), ("letrero_crema", "f7ecd0", "dccca4"),
    ("hoja_clara", "a2e472", "56a845"), ("madera_osc", "a06844", "613c25"),
]
assert len(PAL) == 128, len(PAL)
PIDX = {p[0]: i for i, p in enumerate(PAL)}
EMISION = ("luz", "faro", "luz_verde")   # colores que brillan (lámparas, faros, la luz verde del semáforo)

CELLS = 8                      # columnas
FILAS = len(PAL) // CELLS      # filas (16)
CS = 64                        # lado de cada celda en píxeles
TEX_W = CELLS * CS
TEX_H = FILAS * CS
MARGEN = 6.0 / CS              # los degradés no llegan al borde de la celda (no se mezclan colores vecinos)


def hex_rgb(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], dtype=np.float32)


def uv(nombre, t):
    """UV de un punto pintado con el color 'nombre' a la altura relativa t (0 abajo, 1 arriba)."""
    i = PIDX[nombre]
    cx, cy = i % CELLS, i // CELLS
    t = min(max(t, 0.0), 1.0)
    return ((cx + 0.5) / CELLS, (cy + MARGEN + t * (1 - 2 * MARGEN)) / FILAS)


def pixeles(solo=None):
    """Píxeles RGBA (float, filas de abajo hacia arriba como las imágenes de Blender)."""
    arr = np.zeros((TEX_H, TEX_W, 4), dtype=np.float32)
    arr[..., 3] = 1
    for i, (n, top, bot) in enumerate(PAL):
        if solo and n not in solo:
            continue
        cx, cy = i % CELLS, i // CELLS
        a, b = hex_rgb(bot), hex_rgb(top)
        for r in range(CS):
            t = min(max((r / (CS - 1) - MARGEN) / (1 - 2 * MARGEN), 0.0), 1.0)
            arr[cy * CS + r, cx * CS:(cx + 1) * CS, :3] = a + (b - a) * t
    return arr


def imagen(bpy, nombre, carpeta, solo=None):
    """Imagen de Blender con la paleta (y la guarda en 'carpeta' como PNG, para mirarla)."""
    img = bpy.data.images.new(nombre, TEX_W, TEX_H, alpha=False)
    img.pixels.foreach_set(pixeles(solo).ravel())
    img.filepath_raw = os.path.join(carpeta, nombre + ".png")
    img.file_format = "PNG"
    img.save()
    return img
