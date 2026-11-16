# Piezas del mapa V3. Se ejecuta DENTRO de generar_ciudad.py (con exec, en su mismo espacio de
# nombres): usa su paleta, sus funciones de geometría (bm_box, P, obj, pieza...) y escribe en el mismo
# kit_datos.gd que lee Godot.
#
# Estilo de las referencias del V3: colores pastel saturados, formas redondeadas, follaje facetado
# grande y mucha vida en la calle. Todo es propio (no copia de ningún pack): la ciudad sigue siendo
# porteña (taxis negros y amarillos, colectivos, carteles en castellano).
#
# Convenciones (las mismas del kit):
# - Props: origen en el centro de la base y el frente hacia -Y (+Z en Godot).
# - Vehículos: la trompa hacia +X (así los mueve world/auto.gd), sin ruedas: Godot pone la rueda
#   ("rueda_auto" / "rueda_colectivo", con el origen en su centro y el eje en Y) en DATOS["ruedas"].
# - Edificios: como en generar_ciudad.py (fachada en y=0 mirando a -Y).

V3 = []   # piezas nuevas (para las vistas previas)


def v3(nombre):
    V3.append(nombre)
    return nombre


def R_z(a):
    return Matrix.Rotation(a, 4, "Z")


def T(x, y, z):
    return Matrix.Translation((x, y, z))


def doble_cara(bm):
    """Duplica las caras con la normal al revés (láminas que se ven de los dos lados)."""
    caras = list(bm.faces)
    ret = bmesh.ops.duplicate(bm, geom=caras)
    nuevas = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMFace)]
    bmesh.ops.reverse_faces(bm, faces=nuevas)
    return bm


def polilinea(pts, ancho, z0, z1):
    """Cinta de 'ancho' metros siguiendo los puntos (x, y), de z0 a z1 (líneas pintadas)."""
    bms = []
    for a, b in zip(pts, pts[1:]):
        a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
        d = b - a
        if d.length < 1e-5:
            continue
        n = Vector((-d.y, d.x, 0)).normalized() * (ancho / 2)
        ext = d.normalized() * (ancho / 2 * 0.9)
        a2, b2 = a - ext, b + ext
        bms.append(bm_prisma([(a2 + n).xy[:], (b2 + n).xy[:], (b2 - n).xy[:], (a2 - n).xy[:]], z0, z1))
    return bms


def arco_pts(cx, cy, r, a0, a1, n=24):
    return [(cx + r * math.cos(a0 + (a1 - a0) * k / n), cy + r * math.sin(a0 + (a1 - a0) * k / n)) for k in range(n + 1)]


def bm_flor(c, r):
    """Flor diminuta: un octaedro aplastado (8 triángulos)."""
    bm = bmesh.new()
    x, y, z = c
    v = [bm.verts.new((x + r, y, z)), bm.verts.new((x, y + r, z)), bm.verts.new((x - r, y, z)), bm.verts.new((x, y - r, z)),
         bm.verts.new((x, y, z + r * 0.55)), bm.verts.new((x, y, z - r * 0.55))]
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((v[i], v[j], v[4]))
        bm.faces.new((v[j], v[i], v[5]))
    return bm


def bm_sector(r, z_borde, z_punta, a0, a1, cx=0.0, cy=0.0):
    """Gajo de cono (sombrilla): triángulo de la punta al borde, visible de los dos lados."""
    bm = bmesh.new()
    p = bm.verts.new((cx, cy, z_punta))
    a = bm.verts.new((cx + r * math.cos(a0), cy + r * math.sin(a0), z_borde))
    b = bm.verts.new((cx + r * math.cos(a1), cy + r * math.sin(a1), z_borde))
    bm.faces.new((p, a, b))
    return doble_cara(bm)


# ================================================================= vehículos

AUTO_COLORES = ["auto_celeste", "auto_naranja", "auto_amarillo", "auto_verde", "auto_rojo", "auto_blanco"]
RUEDA_AUTO = 0.33
RUEDA_COLECTIVO = 0.5


def rueda(nombre, r, ancho):
    empezar()
    goma = bm_cyl((0, -ancho / 2, 0), (0, ancho / 2, 0), r, r, 14)
    llanta = bm_cyl((0, -ancho / 2 - 0.012, 0), (0, ancho / 2 + 0.012, 0), r * 0.55, r * 0.55, 10)
    taza = bm_cyl((0, -ancho / 2 - 0.03, 0), (0, ancho / 2 + 0.03, 0), r * 0.18, r * 0.18, 6)
    pieza([obj([P(goma, "goma")], bisel=0.03, seg=2), obj([P(llanta, "llanta"), P(taza, "rejilla")])], v3(nombre),
          sombra=False, rango=100)


def auto(nombre, perfil, cabina, techo_x, color, color_techo=None, ruedas_x=(1.22, -1.22), ancho=1.74, extra=None):
    """Auto (sin ruedas) con la trompa hacia +X. perfil y cabina: costados [(x, z)] de la carrocería y
    de los vidrios; techo_x: (x0, x1) del techo."""
    empezar()
    W = ancho
    ct = color_techo or color
    xf = max(x for x, _ in perfil)
    xb = min(x for x, _ in perfil)
    zb = min(z for _, z in cabina)
    zt = max(z for _, z in cabina)
    est = [P(bm_perfil_y(perfil, -W / 2, W / 2), color)]
    vid = [P(bm_perfil_y(cabina, -W / 2 + 0.11, W / 2 - 0.11), "parabrisas", zb, zt)]
    x0, x1 = techo_x
    est.append(P(bm_box(x1 - x0, W - 0.2, 0.09, (x0 + x1) / 2, 0, zt - 0.04), ct))
    xm = x0 + (x1 - x0) * 0.55
    est.append(P(bm_box(0.13, W - 0.2, zt - zb, xm, 0, zb), ct))
    det = []
    for s in (-1, 1):
        det.append(P(bm_box(0.05, 0.34, 0.15, xf + 0.005, s * (W / 2 - 0.3), 0.5), "faro"))
        det.append(P(bm_box(0.05, 0.3, 0.16, xb - 0.005, s * (W / 2 - 0.28), 0.62), "luz_freno"))
        det.append(P(bm_box(0.16, 0.14, 0.1, x1 + 0.35, s * (W / 2 + 0.05), zb + 0.02), ct))
        det.append(P(bm_box(0.18, 0.03, 0.04, xm + 0.35, s * (W / 2 + 0.005), zb - 0.18), "rejilla"))
    det.append(P(bm_box(0.05, W * 0.42, 0.13, xf + 0.005, 0, 0.34), "rejilla"))
    det.append(P(bm_box(0.16, W + 0.03, 0.15, xf - 0.05, 0, 0.18), "interior"))
    det.append(P(bm_box(0.16, W + 0.03, 0.15, xb + 0.05, 0, 0.18), "interior"))
    det.append(P(bm_box(0.03, 0.44, 0.13, xb - 0.03, 0, 0.4), "blanco"))
    for s in (-1, 1):
        for xr in ruedas_x:
            det.append(P(bm_box(0.9, 0.04, 0.12, xr, s * (W / 2 + 0.005), 0.62), "interior"))
    if extra:
        e, d = extra(W, xf, xb, zt)
        est += e
        det += d
    pieza([obj(est, bisel=0.07, seg=2), obj(vid, bisel=0.03), obj(det)], v3(nombre))
    L = xf - xb
    col_caja((0, 0, (zt + 0.05) / 2 + 0.1), (L, W, zt - 0.15))
    DATOS[nombre]["ruedas"] = [(x, s * (W / 2 - 0.04), RUEDA_AUTO) for x in ruedas_x for s in (-1, 1)]
    DATOS[nombre]["radio_rueda"] = RUEDA_AUTO
    DATOS[nombre]["largo"] = round(L, 3)
    DATOS[nombre]["tipo"] = "vehiculo"


HATCH = ([(-1.9, 0.2), (1.9, 0.2), (1.9, 0.66), (1.5, 0.86), (0.9, 0.94), (-1.72, 0.98), (-1.9, 0.86)],
         [(0.92, 0.92), (0.3, 1.42), (-1.25, 1.45), (-1.72, 0.96)], (-1.32, 0.34))
SEDAN = ([(-2.2, 0.22), (2.2, 0.22), (2.2, 0.64), (1.75, 0.82), (1.05, 0.9), (-1.65, 0.95), (-2.2, 0.88)],
         [(1.06, 0.88), (0.42, 1.4), (-0.95, 1.42), (-1.62, 0.93)], (-1.0, 0.46))


def taxi_extra(W, xf, xb, zt):
    return ([P(bm_box(0.42, 0.26, 0.17, -0.25, 0, zt + 0.04), "auto_amarillo")],
            [P(bm_box(0.44, 0.2, 0.1, -0.25, 0, zt + 0.08), "luz")])


def patrullero_extra(W, xf, xb, zt):
    est = [P(bm_box(1.3, 0.34, 0.12, -0.25, 0, zt + 0.04), "semaforo")]
    det = [P(bm_box(0.5, 0.36, 0.12, -0.55, 0, zt + 0.06), "policia"), P(bm_box(0.5, 0.36, 0.12, 0.05, 0, zt + 0.06), "luz_roja")]
    for s in (-1, 1):
        det.append(P(bm_box(xf - xb - 0.6, 0.03, 0.18, (xf + xb) / 2, s * (W / 2 + 0.006), 0.48), "policia"))
    return est, det


def colectivo(nombre, color, franja):
    empezar()
    W = 2.5
    perfil = [(-5.5, 0.35), (5.45, 0.35), (5.55, 0.55), (5.55, 2.75), (5.3, 3.12), (-5.35, 3.12), (-5.5, 2.95)]
    est = [P(bm_perfil_y(perfil, -W / 2, W / 2), color)]
    est.append(P(bm_box(8.8, W - 0.5, 0.3, -0.6, 0, 3.08), "blanco"))
    vid = [P(bm_box(9.9, W + 0.02, 1.15, -0.25, 0, 1.5), "parabrisas"),
           P(bm_box(0.05, W - 0.25, 1.55, 5.54, 0, 1.15), "parabrisas"),
           P(bm_box(0.05, W - 0.7, 0.95, -5.51, 0, 1.75), "parabrisas")]
    det = [P(bm_box(10.9, W + 0.03, 0.2, 0, 0, 1.12), franja),
           P(bm_box(0.06, 1.7, 0.32, 5.53, 0, 2.75), "luz")]
    for x in (4.65, 0.6):
        det.append(P(bm_box(1.0, 0.04, 2.3, x, -W / 2 - 0.005, 0.5), "parabrisas"))
        det.append(P(bm_box(0.05, 0.05, 2.3, x, -W / 2 - 0.025, 0.5), "rejilla"))
    for s in (-1, 1):
        det.append(P(bm_box(0.05, 0.36, 0.18, 5.56, s * (W / 2 - 0.3), 0.7), "faro"))
        det.append(P(bm_box(0.05, 0.3, 0.3, -5.52, s * (W / 2 - 0.25), 0.8), "luz_freno"))
        det.append(P(bm_box(0.25, 0.25, 0.08, 5.5, s * (W / 2 + 0.12), 2.35), "interior"))
        for x in (3.9, -3.0):
            det.append(P(bm_box(1.3, 0.04, 0.16, x, s * (W / 2 + 0.005), 1.0), "interior"))
    det.append(P(bm_box(0.18, W + 0.03, 0.25, 5.47, 0, 0.3), "interior"))
    det.append(P(bm_box(0.18, W + 0.03, 0.25, -5.45, 0, 0.3), "interior"))
    pieza([obj(est, bisel=0.1, seg=2), obj(vid, bisel=0.02), obj(det)], v3(nombre))
    col_caja((0, 0, 1.75), (11.0, W, 2.8))
    DATOS[nombre]["ruedas"] = [(x, s * (W / 2 - 0.12), RUEDA_COLECTIVO) for x in (3.9, -3.0) for s in (-1, 1)]
    DATOS[nombre]["radio_rueda"] = RUEDA_COLECTIVO
    DATOS[nombre]["largo"] = 11.05
    DATOS[nombre]["tipo"] = "vehiculo"


def moto(nombre, color):
    empezar()
    R90 = Matrix.Rotation(math.radians(90), 4, "X")
    goma, llanta = [], []
    for x in (-0.62, 0.62):
        goma.append(transformar(bm_anillo(0.3, 0.17, -0.06, 0.06, 14), T(x, 0, 0.3) @ R90))
        llanta.append(transformar(bm_cyl((0, 0, -0.04), (0, 0, 0.04), 0.17, 0.17, 10), T(x, 0, 0.3) @ R90))
    cuerpo = [bm_blob((0.12, 0, 0.78), 0.24, (1.5, 0.75, 0.6), 1), bm_box(0.5, 0.36, 0.14, 0.45, 0, 0.62),
              bm_box(0.75, 0.3, 0.08, -0.58, 0, 0.62)]
    oscuro = [bm_box(0.6, 0.3, 0.32, -0.02, 0, 0.32), bm_box(0.55, 0.3, 0.12, -0.32, 0, 0.8),
              bm_cyl((0.62, 0, 0.3), (0.42, 0, 1.0), 0.035, 0.035, 6), bm_cyl((0.44, -0.36, 1.02), (0.44, 0.36, 1.02), 0.025, 0.025, 6),
              bm_cyl((-0.25, 0.18, 0.32), (-0.8, 0.18, 0.45), 0.05, 0.05, 6)]
    pieza([obj([P(b, color) for b in cuerpo], bisel=0.03), obj([P(b, "goma") for b in goma] + [P(b, "llanta") for b in llanta]),
           obj([P(b, "interior") for b in oscuro] + [P(bm_box(0.06, 0.16, 0.12, 0.6, 0, 0.82), "faro")])],
          v3(nombre), sombra=False, rango=110)
    col_caja((0, 0, 0.55), (1.9, 0.5, 1.1))


def hacer_vehiculos():
    rueda("rueda_auto", RUEDA_AUTO, 0.24)
    rueda("rueda_colectivo", RUEDA_COLECTIVO, 0.32)
    for c in AUTO_COLORES:
        auto("auto_hatch_" + c[5:], *HATCH, c)
    for c in ("auto_celeste", "auto_rojo", "auto_blanco", "auto_verde"):
        auto("auto_sedan_" + c[5:], *SEDAN, c, ruedas_x=(1.4, -1.4))
    auto("taxi", *SEDAN, "auto_negro", "auto_amarillo", ruedas_x=(1.4, -1.4), extra=taxi_extra)
    auto("patrullero", *SEDAN, "auto_blanco", ruedas_x=(1.4, -1.4), extra=patrullero_extra)
    colectivo("colectivo_verde", "colectivo", "blanco")
    colectivo("colectivo_azul", "toldo_azul", "plastico_amarillo")
    moto("moto_roja", "auto_rojo")
    moto("moto_celeste", "auto_celeste")


# ================================================================= mobiliario de calle


def hacer_calle_v3():
    # Farola alta con el brazo curvo hacia la calle (-Y) y la luz abajo de la cabeza
    empezar()
    m = [bm_cyl((0, 0, 0), (0, 0, 0.4), 0.17, 0.15, 10), bm_cyl((0, 0, 0.4), (0, 0, 5.6), 0.085, 0.07, 10)]
    pts = [(0, -1.5 * (1 - math.cos(math.radians(a))), 5.55 + 0.85 * math.sin(math.radians(a))) for a in range(0, 91, 10)]
    for a, b in zip(pts, pts[1:]):
        m.append(bm_cyl(a, b, 0.065, 0.065, 8))
    _, ye, ze = pts[-1]
    m.append(bm_cyl((0, ye, ze), (0, ye - 0.5, ze), 0.065, 0.065, 8))
    cabeza = [bm_box(0.42, 0.95, 0.16, 0, ye - 0.85, ze - 0.12)]
    luz = [bm_box(0.32, 0.8, 0.03, 0, ye - 0.85, ze - 0.14)]
    col_caja((0, 0, 3.0), (0.22, 0.22, 6.0))
    pieza([obj([P(b, "poste") for b in m + cabeza], bisel=0.02), obj([P(b, "luz") for b in luz])], v3("farola_curva"), rango=150)

    # Semáforo de vereda (de adorno: los de la avenida los maneja world/transito.gd)
    empezar()
    m = [bm_cyl((0, 0, 0), (0, 0, 0.25), 0.13, 0.11, 8), bm_cyl((0, 0, 0.25), (0, 0, 3.2), 0.065, 0.06, 8)]
    caja = [bm_box(0.36, 0.3, 1.0, 0, -0.18, 2.3), bm_box(0.5, 0.04, 1.14, 0, -0.02, 2.23)]
    visera = [bm_box(0.3, 0.16, 0.04, 0, -0.39, z + 0.13) for z in (3.0, 2.7, 2.4)]
    luces = [("luz_roja", 2.98), ("luz_amarilla", 2.68), ("luz_verde", 2.38)]
    lentes = [P(transformar(bm_cyl((0, 0, 0), (0, -0.03, 0), 0.1, 0.1, 10), T(0, -0.33, z)), c) for c, z in luces]
    boton = [bm_box(0.12, 0.1, 0.2, 0, -0.07, 1.1)]
    col_caja((0, 0, 1.6), (0.2, 0.2, 3.2))
    pieza([obj([P(b, "poste") for b in m + boton], bisel=0.015), obj([P(b, "semaforo") for b in caja + visera], bisel=0.02),
           obj(lentes)], v3("semaforo_vereda"), rango=140)

    # Hidrante rojo
    empezar()
    cuerpo = bm_torno([(0.17, 0.03), (0.17, 0.1), (0.13, 0.12), (0.13, 0.55), (0.16, 0.57), (0.16, 0.62), (0.12, 0.66),
                       (0.08, 0.73), (0, 0.75)], 10)
    bocas = [bm_cyl((0, -0.12, 0.42), (0, -0.25, 0.42), 0.065, 0.065, 8), bm_cyl((0.12, 0, 0.45), (0.22, 0, 0.45), 0.05, 0.05, 8),
             bm_cyl((-0.12, 0, 0.45), (-0.22, 0, 0.45), 0.05, 0.05, 8)]
    pieza([obj([P(cuerpo, "hidrante")] + [P(b, "hidrante") for b in bocas], bisel=0.015),
           obj([P(bm_cyl((0, 0, 0.74), (0, 0, 0.8), 0.04, 0.04, 6), "cano"), P(bm_box(0.4, 0.4, 0.03, 0, 0, 0), "piedra_osc")])],
          v3("hidrante"), sombra=False, rango=100)
    DATOS["hidrante"]["col"].cajas.append((Vector((0, 0, 0.38)), Vector((0.36, 0.36, 0.76)), Matrix.Identity(3)))

    # Contenedores de colores (reciclables y basura)
    for nombre, color in (("contenedor_azul", "contenedor_azul"), ("contenedor_amarillo", "contenedor_amarillo")):
        empezar()
        cuerpo = [bm_box(1.7, 1.0, 1.05, 0, 0, 0.18)]
        tapa = bm_perfil_x([(-0.52, 1.23), (0.52, 1.23), (0.4, 1.38), (-0.4, 1.38)], -0.86, 0.86)
        ruedas = [bm_cyl((x, y - 0.08, 0.09), (x, y + 0.08, 0.09), 0.09, 0.09, 8) for x in (-0.65, 0.65) for y in (-0.35, 0.35)]
        aro = [bm_box(1.2, 0.04, 0.24, 0, -0.51, 0.72)]
        pieza([obj([P(b, color) for b in cuerpo] + [P(tapa, color)], bisel=0.04),
               obj([P(b, "hierro") for b in ruedas] + [P(b, "blanco") for b in aro])], v3(nombre), rango=140)
        DATOS[nombre]["col"].cajas.append((Vector((0, 0, 0.69)), Vector((1.7, 1.0, 1.38)), Matrix.Identity(3)))

    # Tacho chico de vereda (verde, sobre su pie)
    empezar()
    pieza([obj([P(bm_torno([(0.24, 0.12), (0.26, 0.95), (0.22, 0.97), (0.0, 0.97)], 10), "contenedor"),
                P(bm_torno([(0.27, 0.95), (0.2, 1.08), (0.0, 1.1)], 10), "tapa_contenedor")], bisel=0.015),
           obj([P(bm_cyl((0, 0, 0), (0, 0, 0.12), 0.12, 0.12, 8), "hierro"),
                P(bm_box(0.18, 0.03, 0.06, 0, -0.255, 0.85), "rejilla")])], v3("tacho"), sombra=False, rango=100)
    DATOS["tacho"]["col"].cajas.append((Vector((0, 0, 0.55)), Vector((0.5, 0.5, 1.1)), Matrix.Identity(3)))

    # Cartel azul de estacionamiento (una "E" blanca)
    empezar()
    letra = [bm_box(0.08, 0.02, 0.38, -0.1, -0.1, 2.11)] + [bm_box(0.26, 0.02, 0.07, 0.0, -0.1, z) for z in (2.11, 2.265, 2.42)]
    pieza([obj([P(bm_cyl((0, 0, 0), (0, 0, 2.6), 0.04, 0.04, 8), "poste"), P(bm_box(0.64, 0.04, 0.64, 0, -0.05, 1.98), "blanco"),
                P(bm_box(0.58, 0.04, 0.58, 0, -0.07, 2.01), "cartel_azul")]), obj([P(b, "blanco") for b in letra])],
          v3("cartel_estacionamiento"), sombra=False, rango=110)

    # Caja eléctrica gris
    empezar()
    pieza([obj([P(bm_box(0.9, 0.45, 1.25, 0, 0, 0.06), "cano"), P(bm_box(0.98, 0.52, 0.06, 0, 0, 1.31), "poste")], bisel=0.02),
           obj([P(bm_box(0.02, 0.02, 1.1, 0, -0.23, 0.13), "rejilla"), P(bm_box(0.25, 0.02, 0.18, -0.22, -0.23, 0.95), "plastico_amarillo"),
                P(bm_box(0.94, 0.48, 0.06, 0, 0, 0), "piedra_osc")])], v3("caja_electrica"), rango=110)
    DATOS["caja_electrica"]["col"].cajas.append((Vector((0, 0, 0.68)), Vector((0.98, 0.52, 1.37)), Matrix.Identity(3)))

    # Cartelera de vereda con afiches de los dos lados
    empezar()
    rng = random.Random(61)
    est = [bm_cyl((x, 0, 0), (x, 0, 2.6), 0.04, 0.04, 6) for x in (-0.65, 0.65)] + [bm_box(1.42, 0.12, 1.75, 0, 0, 0.75)]
    afiches = []
    for s in (-1, 1):
        afiches.append(P(bm_box(1.25, 0.02, 1.58, 0, s * 0.065, 0.83), "blanco"))
        for _ in range(4):
            w, h = rng.uniform(0.3, 0.9), rng.uniform(0.25, 0.6)
            afiches.append(P(bm_box(w, 0.02, h, rng.uniform(-0.6 + w / 2, 0.6 - w / 2), s * 0.075, rng.uniform(0.9, 2.35 - h)),
                             rng.choice(("toldo_rojo", "auto_celeste", "plastico_amarillo", "flor_rosa", "toldo_verde", "naranja"))))
    pieza([obj([P(b, "hierro") for b in est], bisel=0.01), obj(afiches)], v3("cartelera"), rango=120)
    DATOS["cartelera"]["col"].cajas.append((Vector((0, 0, 1.62)), Vector((1.42, 0.14, 1.75)), Matrix.Identity(3)))

    # Tapa de cloaca (en la vereda o la calle)
    empezar()
    pieza([obj([P(bm_cyl((0, 0, 0), (0, 0, 0.025), 0.36, 0.36, 14), "rejilla")] +
               [P(bm_box(0.6, 0.04, 0.01, 0, y, 0.025), "metal") for y in (-0.2, -0.1, 0.0, 0.1, 0.2)])],
          v3("tapa_cloaca"), sombra=False, rango=60)

    # Obras en la vereda: valla de rayas, pozo con un caño y tierra amontonada
    empezar()
    est = []
    for x in (-0.75, 0.75):
        est += [bm_cyl((x, -0.25, 0), (x, 0, 1.05), 0.03, 0.03, 6), bm_cyl((x, 0.25, 0), (x, 0, 1.05), 0.03, 0.03, 6)]
    rayas = []
    for z in (0.8, 0.42):
        for k in range(6):
            rayas.append(P(bm_box(0.27, 0.04, 0.2, -0.675 + k * 0.27, 0, z), "valla_roja" if k % 2 == 0 else "blanco"))
    pieza([obj([P(b, "poste") for b in est]), obj(rayas)], v3("valla_obra"), sombra=False, rango=110)
    DATOS["valla_obra"]["col"].cajas.append((Vector((0, 0, 0.55)), Vector((1.6, 0.5, 1.1)), Matrix.Identity(3)))

    empezar()
    rng = random.Random(62)
    piso = [bm_box(2.4, 1.5, 0.03, 0, 0, 0), bm_box(1.9, 1.0, 0.012, 0, 0, 0.03)]
    bordes = []
    for _ in range(9):
        a = rng.uniform(0, 2 * math.pi)
        x, y = 1.25 * math.cos(a), 0.8 * math.sin(a)
        bordes.append(transformar(bm_box(rng.uniform(0.25, 0.5), rng.uniform(0.2, 0.4), 0.06, 0, 0, 0), T(x, y, 0) @ R_z(rng.uniform(0, 3))))
    caño = transformar(bm_cyl((-0.9, 0, 0.14), (0.9, 0, 0.14), 0.13, 0.13, 10), R_z(0.15))
    monton = [bm_blob((1.55, 0.55, 0.0), 0.5, (1.2, 1, 0.55), 1, 0.12, rng), bm_blob((1.75, 0.1, 0.0), 0.35, (1, 1, 0.55), 1, 0.1, rng)]
    pieza([obj([P(piso[0], "tierra_obra"), P(piso[1], "tierra")] + [P(b, "lajas_osc") for b in bordes]),
           obj([P(caño, "cano_obra")], bisel=0.02), obj([P(b, "tierra_obra") for b in monton])], v3("pozo_obra"), sombra=False, rango=110)

    # Mesa de café con dos sillas y sombrilla de gajos
    for nombre, tela in (("mesa_cafe_roja", "toldo_rojo"), ("mesa_cafe_verde", "toldo_verde")):
        empezar()
        mesa = [bm_torno([(0.24, 0.0), (0.2, 0.04), (0.035, 0.06), (0.035, 0.7), (0.4, 0.71), (0.4, 0.75), (0, 0.75)], 12)]
        sillas = []
        for s in (-1, 1):
            x = s * 0.7
            sillas.append(bm_box(0.42, 0.42, 0.05, x, 0, 0.44))
            sillas.append(bm_box(0.05, 0.42, 0.45, x + s * 0.19, 0, 0.49))
            for dx in (-0.17, 0.17):
                for dy in (-0.17, 0.17):
                    sillas.append(bm_cyl((x + dx, dy, 0), (x + dx, dy, 0.44), 0.018, 0.018, 4))
        palo = [bm_cyl((0, 0, 0.75), (0, 0, 2.45), 0.025, 0.025, 6)]
        gajos = [P(bm_sector(1.35, 2.05, 2.45, 2 * math.pi * k / 8, 2 * math.pi * (k + 1) / 8),
                   "sombrilla_crema" if k % 2 == 0 else tela) for k in range(8)]
        pieza([obj([P(b, "blanco") for b in mesa], bisel=0.01), obj([P(b, "hierro") for b in sillas + palo]), obj(gajos)],
              v3(nombre), rango=110)
        c = DATOS[nombre]["col"]
        c.cajas.append((Vector((0, 0, 0.38)), Vector((0.8, 0.8, 0.76)), Matrix.Identity(3)))
        c.cajas.append((Vector((0, 0, 2.2)), Vector((1.9, 1.9, 0.3)), Matrix.Identity(3)))

    # Banco de plaza de listones (como en las referencias), mirando a -Y
    empezar()
    listones = [bm_box(1.9, 0.11, 0.05, 0, -0.18 + k * 0.13, 0.45) for k in range(4)]
    listones += [bm_box(1.9, 0.05, 0.11, 0, 0.27, 0.62 + k * 0.15) for k in range(3)]
    patas = []
    for x in (-0.8, 0.8):
        patas += [bm_box(0.07, 0.5, 0.06, x, 0, 0.4), bm_box(0.07, 0.06, 0.45, x, -0.2, 0), bm_box(0.07, 0.06, 0.95, x, 0.24, 0)]
    pieza([obj([P(b, "madera") for b in listones], bisel=0.012), obj([P(b, "hierro") for b in patas])], v3("banco_listones"), rango=110)
    c = DATOS["banco_listones"]["col"]
    c.cajas.append((Vector((0, 0.0, 0.47)), Vector((1.9, 0.55, 0.1)), Matrix.Identity(3)))
    c.cajas.append((Vector((0, 0.27, 0.8)), Vector((1.9, 0.08, 0.5)), Matrix.Identity(3)))


# ================================================================= árboles, arbustos y flores


def arbol_grande(nombre, seed, alto, r_copa, n=7, color="hoja", ramas=3):
    """Árbol grande de copa redonda hecha de bollos facetados (como los de las referencias)."""
    empezar()
    rng = random.Random(seed)
    tr = [bm_cyl((0, 0, 0), (0, 0, alto), 0.33, 0.2, 7)]
    for k in range(4):
        a = k * math.pi / 2 + rng.uniform(-0.4, 0.4)
        tr.append(bm_cyl((0, 0, 0.4), (0.6 * math.cos(a), 0.6 * math.sin(a), 0.0), 0.15, 0.07, 5))
    cz = alto + r_copa * 0.5
    bollos = [((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), cz + r_copa * 0.5), r_copa * 0.62)]
    for k in range(n):
        a = 2 * math.pi * k / n + rng.uniform(-0.25, 0.25)
        d = r_copa * rng.uniform(0.55, 0.72)
        z = cz + rng.uniform(-0.28, 0.15) * r_copa
        bollos.append(((d * math.cos(a), d * math.sin(a), z), r_copa * rng.uniform(0.42, 0.54)))
        if k < ramas:
            tr.append(bm_cyl((0, 0, alto * 0.82), (d * 0.6 * math.cos(a), d * 0.6 * math.sin(a), z - r_copa * 0.25), 0.13, 0.07, 5))
    z0 = min(c[2] - r for c, r in bollos)
    z1 = max(c[2] + r for c, r in bollos)
    hojas = [P(bm_blob(c, r, (1, 1, 0.92), 2, 0.05, rng), color, z0, z1) for c, r in bollos]
    col_esfera((0, 0, cz + 0.15 * r_copa), r_copa * 0.95)
    col_caja((0, 0, alto / 2), (0.5, 0.5, alto))
    pieza([obj([P(b, "tronco") for b in tr]), obj(hojas)], v3(nombre), rango=170)


def pino(nombre, seed, alto, r_base, pisos=5):
    """Pino de conos apilados, facetado."""
    empezar()
    rng = random.Random(seed)
    tr = [bm_cyl((0, 0, 0), (0, 0, alto * 0.3), 0.2, 0.14, 6)]
    conos = []
    z = alto * 0.14
    for k in range(pisos):
        f = 1 - k / pisos
        r = r_base * (0.3 + 0.7 * f)
        h = alto * 0.3 * (0.65 + 0.35 * f)
        c = bm_cyl((0, 0, z), (0, 0, z + h), r, 0.03, 8)
        transformar(c, R_z(rng.uniform(0, 1.0)))
        conos.append(c)
        z += h * 0.5
    conos.append(bm_cyl((0, 0, z), (0, 0, z + alto * 0.12), r_base * 0.18, 0.01, 6))
    zt = z + alto * 0.12
    col_caja((0, 0, zt / 2 + 0.3), (r_base * 1.2, r_base * 1.2, zt - 0.6))
    pieza([obj([P(b, "tronco") for b in tr]), obj([P(b, "pino", 0, zt) for b in conos])], v3(nombre), rango=170)


def arbusto_redondo(nombre, seed, bollos, color="hoja"):
    empezar()
    rng = random.Random(seed)
    z1 = max(c[2] + r for c, r in bollos)
    pieza([obj([P(bm_blob(c, r, (1, 1, 0.85), 1, 0.08, rng), color, 0, z1) for c, r in bollos])], v3(nombre), sombra=False, rango=110)


COLORES_FLOR = ("flor_rosa", "flor_amarilla", "flor_azul", "flor_blanca", "flor_naranja", "flor_violeta", "flor_roja")


def flores(nombre, seed, ancho, n, colores=COLORES_FLOR, hojas=3):
    """Mata de flores: unos bollos bajos de hojas y flores diminutas de colores encima."""
    empezar()
    rng = random.Random(seed)
    m = ancho / 2
    hj = [bm_blob((rng.uniform(-m * 0.5, m * 0.5), rng.uniform(-m * 0.5, m * 0.5), 0.02), rng.uniform(0.3, 0.42) * ancho / 1.4,
                  (1, 1, 0.5), 1, 0.12, rng) for _ in range(hojas)]
    fl = []
    for _ in range(n):
        a = rng.uniform(0, 2 * math.pi)
        d = m * math.sqrt(rng.random()) * 0.9
        fl.append(P(bm_flor((d * math.cos(a), d * math.sin(a), rng.uniform(0.16, 0.3)), rng.uniform(0.06, 0.09)), rng.choice(colores)))
    pieza([obj([P(b, "hoja_osc") for b in hj]), obj(fl)], v3(nombre), sombra=False, rango=90)


def mata_pasto(nombre, seed):
    """Mata de pasto alto: hojas finas en abanico (láminas de dos caras)."""
    empezar()
    rng = random.Random(seed)
    hojas = []
    for _ in range(9):
        a = rng.uniform(0, 2 * math.pi)
        inc = rng.uniform(0.15, 0.45)
        h = rng.uniform(0.35, 0.6)
        bm = bmesh.new()
        p0 = bm.verts.new((-0.035, 0, 0))
        p1 = bm.verts.new((0.035, 0, 0))
        p2 = bm.verts.new((0, h * math.sin(inc), h * math.cos(inc)))
        bm.faces.new((p0, p1, p2))
        doble_cara(bm)
        hojas.append(P(transformar(bm, R_z(a)), "pasto_claro", 0, 0.6))
    pieza([obj(hojas)], v3(nombre), sombra=False, rango=70)


def hacer_parque_v3():
    arbol_grande("arbol_grande_A", 71, 2.7, 2.8, 7)
    arbol_grande("arbol_grande_B", 72, 3.1, 2.3, 6, "hoja_osc")
    arbol_grande("arbol_grande_C", 73, 2.3, 3.3, 8)
    arbol_grande("jacaranda_grande", 74, 2.6, 2.6, 7, "jacaranda")
    pino("pino_A", 75, 8.5, 2.1, 5)
    pino("pino_B", 76, 6.5, 1.7, 4)
    arbusto_redondo("arbusto_redondo_A", 77, [((0, 0, 0.45), 0.6), ((0.45, 0.2, 0.32), 0.42), ((-0.4, -0.15, 0.3), 0.4)])
    arbusto_redondo("arbusto_redondo_B", 78, [((0, 0, 0.6), 0.75), ((0.55, -0.1, 0.38), 0.5)], "hoja_osc")
    flores("flores_A", 81, 1.4, 22)
    flores("flores_B", 82, 1.2, 18, ("flor_rosa", "flor_violeta", "flor_blanca"))
    flores("flores_C", 83, 1.6, 26, ("flor_amarilla", "flor_naranja", "flor_roja", "flor_blanca"))
    flores("flores_D", 84, 1.3, 20, ("flor_azul", "flor_blanca", "flor_rosa"))
    mata_pasto("mata_pasto", 85)


# ================================================================= juegos de plaza


def hacer_juegos_v3():
    # Tobogán con torre, techito, escalera y una pared de escalar con discos de colores
    empezar()
    h = 1.5
    tubos = [bm_cyl((x, y, 0), (x, y, h + 1.05), 0.05, 0.05, 8) for x in (-0.58, 0.58) for y in (-0.58, 0.58)]
    plataforma = [bm_box(1.3, 1.3, 0.1, 0, 0, h)]
    techo = transformar(bm_torno([(1.0, 0), (0.0, 0.6)], 4), T(0, 0, h + 1.05) @ R_z(math.pi / 4))
    ang = math.atan2(h, 2.6)
    L = math.hypot(2.6, h)
    M = T(0.62, 0, h + 0.05) @ Matrix.Rotation(ang, 4, "Y")
    chute = [transformar(bm_box(L, 0.62, 0.06, L / 2, 0, 0), M)] + [transformar(bm_box(L, 0.06, 0.26, L / 2, s * 0.31, 0), M) for s in (-1, 1)]
    chute.append(bm_box(0.6, 0.62, 0.06, 3.5, 0, 0.12))
    escalera = [bm_cyl((-0.62, s * 0.3, 0), (-0.62, s * 0.3, h + 0.6), 0.035, 0.035, 6) for s in (-1, 1)]
    escalera += [bm_cyl((-0.62, -0.3, z), (-0.62, 0.3, z), 0.03, 0.03, 6) for z in (0.3, 0.6, 0.9, 1.2)]
    pared = [bm_box(1.2, 0.08, 1.3, 0, 0.66, 0.15)]
    discos = []
    rng = random.Random(91)
    for k in range(7):
        x, z = rng.uniform(-0.45, 0.45), rng.uniform(0.35, 1.3)
        discos.append(P(bm_cyl((x, 0.7, z), (x, 0.74, z), 0.1, 0.1, 10), rng.choice(("plastico_amarillo", "plastico_rojo", "plastico_verde"))))
    pieza([obj([P(b, "plastico_azul") for b in tubos + escalera] + [P(b, "plastico_amarillo") for b in plataforma], bisel=0.015),
           obj([P(techo, "plastico_rojo")] + [P(b, "plastico_rojo") for b in chute], bisel=0.02),
           obj([P(b, "plastico_azul") for b in pared] + discos)], v3("tobogan_torre"))
    c = DATOS["tobogan_torre"]["col"]
    c.cajas.append((Vector((0, 0, (h + 1.65) / 2)), Vector((1.3, 1.3, h + 1.65)), Matrix.Identity(3)))
    c.cajas.append((M @ Vector((L / 2, 0, 0.1)), Vector((L, 0.65, 0.2)), M.to_3x3()))

    # Hamaca de madera en A (los asientos son "hamaca_asiento", colgados a 2,5 m)
    empezar()
    patas = []
    for x in (-1.55, 1.55):
        for y in (-0.75, 0.75):
            patas.append(bm_cyl((x, y, 0), (x, 0, 2.55), 0.07, 0.06, 6))
    viga = [bm_cyl((-1.75, 0, 2.55), (1.75, 0, 2.55), 0.09, 0.09, 8)]
    pieza([obj([P(b, "madera") for b in patas + viga], bisel=0.02)], v3("hamaca_madera"))
    c = DATOS["hamaca_madera"]["col"]
    for x in (-1.55, 1.55):
        c.cajas.append((Vector((x, 0, 1.3)), Vector((0.2, 1.5, 2.6)), Matrix.Identity(3)))
    c.cajas.append((Vector((0, 0, 2.55)), Vector((3.5, 0.2, 0.2)), Matrix.Identity(3)))

    # Caballitos de resorte: un dinosaurio verde y un elefante celeste
    for nombre, color, bicho in (("resorte_dino", "plastico_verde", "dino"), ("resorte_elefante", "auto_celeste", "elefante")):
        empezar()
        rng = random.Random(92)
        base = [bm_cyl((0, 0, 0), (0, 0, 0.06), 0.3, 0.3, 10)]
        resorte = [bm_anillo(0.12, 0.085, 0.08 + k * 0.055, 0.11 + k * 0.055, 10) for k in range(6)]
        cuerpo = [bm_blob((0, 0, 0.62), 0.3, (1.45, 0.75, 0.8), 1)]
        if bicho == "dino":
            cuerpo += [bm_cyl((0.3, 0, 0.7), (0.45, 0, 0.98), 0.1, 0.08, 6), bm_blob((0.5, 0, 1.03), 0.16, (1.3, 0.85, 0.85), 1),
                       bm_cyl((-0.38, 0, 0.62), (-0.8, 0, 0.5), 0.13, 0.02, 6)]
            cuerpo += [bm_cyl((-0.15 + k * 0.15, 0, 0.82), (-0.15 + k * 0.15, 0, 0.98), 0.06, 0.0, 4) for k in range(3)]
        else:
            cuerpo += [bm_blob((0.42, 0, 0.85), 0.22, (1, 1, 0.95), 1), bm_cyl((0.6, 0, 0.82), (0.75, 0, 0.45), 0.07, 0.04, 6)]
            cuerpo += [bm_blob((0.38, s * 0.22, 0.88), 0.16, (0.6, 0.3, 1), 1) for s in (-1, 1)]
        ojos = [bm_blob((0.62 if bicho == "dino" else 0.58, s * 0.09, 1.08 if bicho == "dino" else 0.92), 0.03, sub=1) for s in (-1, 1)]
        manijas = [bm_cyl((0.22, -0.2, 0.95), (0.22, 0.2, 0.95), 0.025, 0.025, 6), bm_cyl((0.22, 0, 0.85), (0.22, 0, 0.95), 0.025, 0.025, 6)]
        pieza([obj([P(b, "piedra_osc") for b in base] + [P(b, "cano") for b in resorte]),
               obj([P(b, color) for b in cuerpo], bisel=0.01),
               obj([P(bm_box(0.32, 0.34, 0.05, -0.05, 0, 0.84), "plastico_rojo")] + [P(b, "plastico_amarillo") for b in manijas] +
                   [P(b, "hierro") for b in ojos])], v3(nombre), rango=110)
        DATOS[nombre]["col"].cajas.append((Vector((0, 0, 0.5)), Vector((1.0, 0.5, 1.0)), Matrix.Identity(3)))

    # Cerco de palos de colores (tramo de 3 m)
    empezar()
    palos = []
    colores = ("plastico_rojo", "naranja", "plastico_amarillo", "plastico_verde", "plastico_azul", "flor_violeta")
    for k in range(12):
        x = -1.375 + k * 0.25
        pf = [(x - 0.07, 0), (x + 0.07, 0), (x + 0.07, 0.72), (x, 0.86), (x - 0.07, 0.72)]
        palos.append(P(bm_perfil_y(pf, -0.025, 0.025), colores[k % len(colores)]))
    rieles = [bm_box(3.0, 0.04, 0.08, 0, 0.045, z) for z in (0.18, 0.55)]
    pieza([obj(palos), obj([P(b, "madera") for b in rieles])], v3("cerco_colores"), sombra=False, rango=110)
    DATOS["cerco_colores"]["col"].cajas.append((Vector((0, 0, 0.43)), Vector((3.0, 0.12, 0.86)), Matrix.Identity(3)))

    # Aro de básquet (el tablero mira hacia -Y)
    empezar()
    est = [bm_cyl((0, 1.0, 0), (0, 1.0, 3.35), 0.08, 0.07, 8), bm_box(0.12, 0.95, 0.12, 0, 0.55, 3.15)]
    tablero = [bm_box(1.8, 0.06, 1.05, 0, 0.1, 2.85)]
    lineas = [bm_box(0.62, 0.012, 0.05, 0, 0.065, z) for z in (3.0, 3.42)] + [bm_box(0.05, 0.012, 0.47, x, 0.065, 3.0) for x in (-0.29, 0.29)]
    lineas += [bm_box(1.8, 0.012, 0.06, 0, 0.065, z) for z in (2.85, 3.84)] + [bm_box(0.06, 0.012, 1.05, x, 0.065, 2.85) for x in (-0.87, 0.87)]
    aro = [bm_anillo(0.24, 0.21, 3.03, 3.06, 14, 0, -0.18), bm_box(0.06, 0.12, 0.03, 0, 0.0, 3.03)]
    red = []
    for k in range(8):
        a = 2 * math.pi * k / 8
        red.append(bm_cyl((0.225 * math.cos(a), -0.18 + 0.225 * math.sin(a), 3.03),
                          (0.13 * math.cos(a + 0.4), -0.18 + 0.13 * math.sin(a + 0.4), 2.65), 0.008, 0.008, 3))
    pieza([obj([P(b, "poste") for b in est], bisel=0.02), obj([P(b, "blanco") for b in tablero], bisel=0.015),
           obj([P(b, "naranja") for b in lineas + aro] + [P(b, "blanco") for b in red])], v3("aro_basquet"))
    c = DATOS["aro_basquet"]["col"]
    c.cajas.append((Vector((0, 1.0, 1.7)), Vector((0.18, 0.18, 3.35)), Matrix.Identity(3)))
    c.cajas.append((Vector((0, 0.1, 3.37)), Vector((1.8, 0.08, 1.05)), Matrix.Identity(3)))

    # Cancha de básquet de 26 x 14 m (piso pintado con sus líneas)
    empezar()
    L, A = 26.0, 14.0
    piso = [bm_box(L + 2.0, A + 2.0, 0.035, 0, 0, 0)]
    cancha = [bm_box(L, A, 0.01, 0, 0, 0.035)]
    z0, z1 = 0.045, 0.052
    w = 0.09
    lineas = polilinea([(-L / 2, -A / 2), (L / 2, -A / 2), (L / 2, A / 2), (-L / 2, A / 2), (-L / 2, -A / 2)], w, z0, z1)
    lineas += polilinea([(0, -A / 2), (0, A / 2)], w, z0, z1)
    lineas += polilinea(arco_pts(0, 0, 1.8, 0, 2 * math.pi, 28), w, z0, z1)
    for s in (-1, 1):
        xb = s * L / 2
        xl = s * (L / 2 - 5.8)
        lineas += polilinea([(xb, -2.45), (xl, -2.45), (xl, 2.45), (xb, 2.45)], w, z0, z1)
        lineas += polilinea(arco_pts(xl, 0, 1.8, math.pi / 2, 3 * math.pi / 2, 14) if s > 0 else
                            arco_pts(xl, 0, 1.8, -math.pi / 2, math.pi / 2, 14), w, z0, z1)
        xc = s * (L / 2 - 1.575)
        lineas += polilinea([(xb, -6.6), (s * (L / 2 - 1.6), -6.6)], w, z0, z1)
        lineas += polilinea([(xb, 6.6), (s * (L / 2 - 1.6), 6.6)], w, z0, z1)
        a = math.asin(6.6 / 6.75)
        lineas += polilinea(arco_pts(xc, 0, 6.75, math.pi - a, math.pi + a, 30) if s > 0 else arco_pts(xc, 0, 6.75, -a, a, 30), w, z0, z1)
    pieza([obj([P(piso[0], "lajas_osc"), P(cancha[0], "cancha")] + [P(b, "blanco") for b in lineas])], v3("cancha_basquet"),
          sombra=False)
    DATOS["cancha_basquet"]["tipo"] = "piso"

    empezar()
    pieza([obj([P(bm_blob((0, 0, 0.12), 0.12, sub=2), "naranja")]), obj([P(bm_anillo(0.122, 0.115, 0.115, 0.125, 12), "hierro")])],
          v3("pelota"), sombra=False, rango=60)


# ================================================================= íconos de los carteles


def icono(F, tipo, u, z, off):
    """Dibujo en relieve sobre un cartel de la fachada F, centrado en (u, z), a 'off' de la pared."""
    def perfil(pts, color, d=0.04):
        return P(F.local(bm_perfil_y([(u + x, z + y) for x, y in pts], off, off + d)), color)

    def L_(bm, color):
        return P(F.local(bm), color)
    # En el marco de la fachada la "y" local sale de la pared; los perfiles se dibujan en el plano (u, z)
    # y bm_perfil_y los extruye hacia afuera.
    out = []
    if tipo == "pan":
        out.append(L_(bm_blob((u, off + 0.04, z), 0.17, (1.5, 0.45, 0.75), 2), "arena"))
        for dx in (-0.1, 0.0, 0.1):
            out.append(L_(bm_box(0.035, 0.03, 0.14, u + dx, off + 0.1, z - 0.04), "madera"))
    elif tipo == "llave":
        M = T(u, off, z) @ Matrix.Rotation(math.radians(40), 4, "Y")
        out.append(L_(transformar(bm_box(0.07, 0.04, 0.4, 0, 0.02, -0.26), M), "blanco"))
        out.append(L_(transformar(bm_anillo(0.11, 0.05, 0, 0.04, 10), M @ T(0, 0, 0.2) @ Matrix.Rotation(math.radians(-90), 4, "X")),
                      "blanco"))
    elif tipo == "carrito":
        out.append(perfil([(-0.2, -0.06), (0.15, -0.06), (0.2, 0.14), (-0.24, 0.14)], "blanco"))
        out.append(perfil([(-0.24, 0.14), (-0.21, 0.14), (-0.28, 0.24), (-0.31, 0.24)], "blanco"))
        for dx in (-0.13, 0.1):
            out.append(L_(bm_cyl((u + dx, off, z - 0.12), (u + dx, off + 0.05, z - 0.12), 0.045, 0.045, 8), "blanco"))
    elif tipo == "caramelo":
        out.append(L_(bm_blob((u, off + 0.04, z), 0.11, (1, 0.5, 1), 2), "flor_rosa"))
        out.append(perfil([(-0.1, 0), (-0.25, 0.09), (-0.25, -0.09)], "plastico_amarillo"))
        out.append(perfil([(0.1, 0), (0.25, -0.09), (0.25, 0.09)], "plastico_amarillo"))
    elif tipo == "remera":
        out.append(perfil([(-0.1, -0.2), (0.1, -0.2), (0.1, 0.04), (0.2, -0.01), (0.25, 0.1), (0.12, 0.2), (0.05, 0.2), (0.0, 0.15),
                           (-0.05, 0.2), (-0.12, 0.2), (-0.25, 0.1), (-0.2, -0.01), (-0.1, 0.04)], "naranja"))
    elif tipo == "taza":
        out.append(perfil([(-0.12, -0.15), (0.12, -0.15), (0.14, 0.1), (-0.14, 0.1)], "blanco"))
        out.append(L_(transformar(bm_anillo(0.08, 0.045, -0.02, 0.02, 10), T(u - 0.16, off + 0.02, z - 0.03) @
                                  Matrix.Rotation(math.radians(90), 4, "X")), "blanco"))
        out.append(perfil([(-0.06, 0.14), (-0.03, 0.14), (-0.01, 0.26), (-0.04, 0.26)], "blanco", 0.02))
        out.append(perfil([(0.03, 0.14), (0.06, 0.14), (0.08, 0.26), (0.05, 0.26)], "blanco", 0.02))
    elif tipo in ("cruz_verde", "cruz_roja"):
        c = "toldo_verde" if tipo == "cruz_verde" else "cruz_roja"
        out.append(L_(bm_box(0.36, 0.05, 0.12, u, off + 0.025, z - 0.06), c))
        out.append(L_(bm_box(0.12, 0.05, 0.36, u, off + 0.025, z - 0.18), c))
    elif tipo == "escudo":
        pts = []
        for k in range(10):
            a = math.pi / 2 + 2 * math.pi * k / 10
            r = 0.2 if k % 2 == 0 else 0.09
            pts.append((r * math.cos(a), r * math.sin(a)))
        out.append(perfil(pts, "plastico_amarillo"))
    return out


# ================================================================= locales y edificios especiales


def letrero(F, W, z, color, ico, tipo, ancho=None):
    """Cartel con ícono a la izquierda y lugar para el texto (lo escribe Godot según 'tipo')."""
    a = ancho or W * 0.6
    est = [P(F.caja(0, z - 0.4, a, 0.8, 0.12), color)]
    det = icono(F, ico, a / 2 - 0.45, z, 0.13)
    F.cartel(-0.4, z, a - 1.2, 0.55, 0.125, tipo)
    return est, det


def extra_taller(F, H, rng):
    W = F.w
    est, det = [], []
    for s in (-1, 1):
        u = s * W / 4
        est.append(P(F.caja(u, 0, 3.7, 3.35, 0.1), "remate_marron"))
        det.append(P(F.caja(u, 0, 3.3, 3.05, 0.15), "goma_azul"))
        for j in range(9):
            det.append(P(F.caja(u, 0.22 + j * 0.31, 3.3, 0.035, 0.16), "remate_azul"))
    e, d = letrero(F, W, 3.75, "letrero", "llave", "taller")
    est += e
    det += d
    for k in range(3):
        det.append(P(F.local(bm_cyl((-0.3, 0.55, 0.05 + k * 0.24), (-0.3, 0.55, 0.27 + k * 0.24), 0.36, 0.36, 12)), "goma"))
    F.col(-0.3, 0, 0.75, 0.75, 0.75, 0.2)
    return est, det


def extra_ropa(F, H, rng):
    W = F.w
    det = []
    for k, (u, c) in enumerate(((-1.6, "toldo_rojo"), (1.4, "plastico_amarillo"), (0.0, "auto_celeste"))):
        det.append(P(F.local(bm_perfil_y([(u - 0.3, 0.9), (u + 0.3, 0.9), (u + 0.3, 1.9), (u + 0.55, 1.75), (u + 0.65, 2.05),
                                          (u + 0.25, 2.3), (u - 0.25, 2.3), (u - 0.65, 2.05), (u - 0.55, 1.75), (u - 0.3, 1.9)], 0.111,
                                         0.12)), c))
    return [], det


def extra_hospital(F, H, rng):
    W = F.w
    est, det = [], []
    # Marquesina de la entrada principal y franja roja arriba de la planta baja
    est.append(P(F.caja(0, 3.05, 6.0, 0.28, 2.8), "hospital"))
    est.append(P(F.caja(0, 3.0, 6.04, 0.16, 0.06, 2.8), "cruz_roja"))
    for s in (-1, 1):
        det.append(P(F.caja(s * 2.75, 0, 0.18, 3.05, 0.18, 2.5), "hospital"))
    F.col(0, 3.05, 6.0, 0.28, 2.8)
    # Cartel grande con la cruz roja y "HOSPITAL"
    zc = PB + 2 * PISO + 0.4
    est.append(P(F.caja(0, zc - 0.8, 11.0, 1.6, 0.2), "hospital"))
    est.append(P(F.caja(0, zc - 0.85, 11.1, 0.1, 0.22), "cruz_roja"))
    det.append(P(F.caja(4.6, zc - 0.17, 1.1, 0.34, 0.08, 0.2), "cruz_roja"))
    det.append(P(F.caja(4.6, zc - 0.55, 0.34, 1.1, 0.08, 0.2), "cruz_roja"))
    F.cartel(-0.7, zc, 8.6, 1.1, 0.21, "hospital")
    # Entrada de la guardia, a un costado, con su techito y cartel rojo
    ug = -(W / 2 - 3.5)
    est.append(P(F.caja(ug, 2.9, 4.2, 0.22, 2.2), "hospital"))
    det.append(P(F.caja(ug, 0, 2.6, 2.8, 0.1), "vidrio_osc"))
    est.append(P(F.caja(ug, 3.15, 3.2, 0.55, 0.14, 0.05), "cruz_roja"))
    F.cartel(ug, 3.42, 3.0, 0.42, 0.2, "guardia")
    F.col(ug, 2.9, 4.2, 0.22, 2.2)
    # Helipuerto en la azotea (del lado izquierdo, que queda libre de equipos)
    hx, hy = W / 4, 8.0
    det.append(P(bm_cyl((hx, hy, H + 0.06), (hx, hy, H + 0.1), 3.4, 3.4, 24), "blanco"))
    det.append(P(bm_anillo(3.1, 2.8, H + 0.1, H + 0.115, 24, hx, hy), "cruz_roja"))
    for dx in (-0.55, 0.55):
        det.append(P(bm_box(0.3, 1.8, 0.015, hx + dx, hy, H + 0.1), "cruz_roja"))
    det.append(P(bm_box(1.1, 0.3, 0.015, hx, hy, H + 0.1), "cruz_roja"))
    return est, det


def extra_comisaria(F, H, rng):
    W = F.w
    est, det = [], []
    e, d = letrero(F, W, 3.65, "policia", "escudo", "comisaria", ancho=8.0)
    est += e
    det += d
    # Mástil con la bandera en la azotea, sobre el frente
    x = W / 2 - 1.0
    det.append(P(bm_cyl((x, 0.8, H), (x, 0.8, H + 5.0), 0.05, 0.04, 8), "cano"))
    for k, c in enumerate(("fachada_cielo", "blanco", "fachada_cielo")):
        det.append(P(bm_box(1.6, 0.03, 0.32, x - 0.82, 0.8, H + 4.55 - k * 0.32), c))
    det.append(P(bm_cyl((x - 0.82, 0.78, H + 4.39), (x - 0.82, 0.76, H + 4.39), 0.08, 0.08, 8), "plastico_amarillo"))
    # Baliza azul en el frente
    det.append(P(bm_box(1.2, 0.3, 0.2, 0, 0.3, H + PRETIL + TAPA), "policia"))
    det.append(P(bm_box(0.4, 0.32, 0.2, -0.4, 0.3, H + PRETIL + TAPA + 0.01), "luz_roja"))
    return est, det


def hacer_edificios_v3():
    E = edificio
    # Locales temáticos (el texto del cartel lo pone Godot según el tipo)
    E("panaderia_8", 8, 16, 2, "clasico", "fachada_crema", 401, pb="local", toldo_col="toldo_naranja", rayas=6,
      remate="naranja", cartel="panaderia", icono="pan", cartel_col="letrero_crema", techo_col="techo")
    E("golosineria_8", 8, 16, 2, "clasico", "fachada_salmon", 402, pb="local", toldo_col="toldo_rojo", rayas=6,
      remate="blanco", cartel="golosineria", icono="caramelo", cartel_col="blanco")
    E("farmacia_8", 8, 16, 3, "ladrillo", "hospital", 403, pb="local", remate="toldo_verde", cartel="farmacia",
      icono="cruz_verde", cartel_col="toldo_verde")
    E("minimercado_10", 10, 16, 2, "ladrillo", "fachada_menta", 404, pb="local", remate="blanco", cartel="minimercado",
      icono="carrito", cartel_col="remate_verde")
    E("ropa_10", 10, 16, 2, "clasico", "fachada_cielo", 405, pb="local", remate="blanco", cartel="ropa", icono="remera",
      cartel_col="blanco", extra=extra_ropa)
    E("cafe_10", 10, 16, 3, "clasico", "ladrillo", 406, pb="local", toldo_col="toldo_verde", remate="remate_crema",
      cartel="cafe", icono="taza", cartel_col="kiosco")
    E("taller_12", 12, 16, 2, "ladrillo", "fachada_mostaza", 407, pb="vacia", remate="remate_marron", extra=extra_taller,
      techo_col="techo")
    # Edificios especiales
    E("hospital_32", 32, 16, 3, "ladrillo", "hospital", 411, pb="entrada", remate="cruz_roja", techo_col="techo",
      extra=extra_hospital, azotea_ocupada=[(8.0, 8.0, 3.6, 3.6)])
    E("comisaria_20", 20, 16, 2, "ladrillo", "policia_claro", 412, pb="entrada", remate="policia", techo_col="techo",
      extra=extra_comisaria)
    for n in ("panaderia_8", "golosineria_8", "farmacia_8", "minimercado_10", "ropa_10", "cafe_10", "taller_12", "hospital_32",
              "comisaria_20"):
        v3(n)
        DATOS[n]["especial"] = True


def hacer_v3():
    hacer_vehiculos()
    hacer_calle_v3()
    hacer_parque_v3()
    hacer_juegos_v3()
    hacer_edificios_v3()
