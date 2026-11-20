# Props de plaza y vereda con más detalle: la fuente y el cantero del parque, las mesas de café con
# sombrilla y los macetones. Reemplazan a las piezas del mismo nombre de generar_parque.py y
# generar_ciudad.py con LAS MISMAS MEDIDAS (huella, alto, colisiones de Kit/KitDatos), así no cambia
# nada más del mapa. Usan la paleta compartida (paleta.py): UV al medio de la celda y V según la altura.
#
#   F:/blender.exe -b --factory-startup -P tools/blender/props_plaza.py [-- --render <carpeta>] [--solo a,b]
#
# Ejes de Blender: Z arriba, el frente de las mesas hacia -Y. Origen en el centro de la base.
# Referencia de estilo: la fuente del parque y la terraza del café del Sparrow Sim (sólo como guía de
# forma: todo se arma acá).

import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paleta  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER = None
SOLO = None
for i, a in enumerate(args):
    if a == "--render":
        RENDER = args[i + 1]
    if a == "--solo":
        SOLO = args[i + 1].split(",")

SALIDAS = {
    "fuente": "modelos/parque/piezas/fuente.glb",
    "cantero": "modelos/parque/piezas/cantero.glb",
    "mesa_cafe_roja": "modelos/ciudad/piezas/mesa_cafe_roja.glb",
    "mesa_cafe_verde": "modelos/ciudad/piezas/mesa_cafe_verde.glb",
    "maceton": "modelos/ciudad/piezas/maceton.glb",
    "maceton_flores": "modelos/ciudad/piezas/maceton_flores.glb",
}
PI = math.pi
TAU = 2 * PI


# ================================================================= geometría
class Pieza:
    """Acumula elementos pintados (bmesh + color + rango de alturas del degradé + sombreado)."""

    def __init__(self):
        self.partes = []

    def add(self, bm, color, z0=None, z1=None, suave=False):
        self.partes.append((bm, color, z0, z1, suave))
        return bm


def torno(perfil, seg=24, cx=0.0, cy=0.0, tapas=True, ondas=None):
    """Sólido de revolución: perfil [(radio, z)] de abajo hacia arriba. ondas=(n, amp) festonea el borde."""
    bm = bmesh.new()
    anillos = []
    for r, z in perfil:
        if r < 1e-6:
            anillos.append([bm.verts.new((cx, cy, z))])
            continue
        fila = []
        for i in range(seg):
            a = TAU * i / seg
            rr = r
            if ondas:
                rr = r * (1 + ondas[1] * math.cos(ondas[0] * a))
            fila.append(bm.verts.new((cx + rr * math.cos(a), cy + rr * math.sin(a), z)))
        anillos.append(fila)
    for a, b in zip(anillos, anillos[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        for i in range(seg):
            j = (i + 1) % seg
            if len(a) == 1:
                bm.faces.new((a[0], b[j], b[i]))
            elif len(b) == 1:
                bm.faces.new((a[i], a[j], b[0]))
            else:
                bm.faces.new((a[i], a[j], b[j], b[i]))
    if tapas:
        if len(anillos[0]) > 1:
            bm.faces.new(list(reversed(anillos[0])))
        if len(anillos[-1]) > 1:
            bm.faces.new(anillos[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def caja(sx, sy, sz, x=0.0, y=0.0, z=0.0, bisel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx + x, v.co.y * sy + y, v.co.z * sz + z + sz / 2))
    if bisel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bisel, segments=1, affect="EDGES", profile=0.5)
    return bm


def cil(p0, p1, r0, r1=None, seg=8):
    r1 = r0 if r1 is None else r1
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    L = d.length
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r0, radius2=r1, depth=L)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation(p0) @ rot @ Matrix.Translation((0, 0, L / 2)), verts=bm.verts)
    return bm


def bollo(c, r, sc=(1, 1, 1), sub=1, jitter=0.0, rng=None):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    for v in bm.verts:
        co = v.co.copy()
        if jitter and rng:
            co += co.normalized() * (rng.uniform(-jitter, jitter) * r)
        v.co = Vector((co.x * sc[0] + c[0], co.y * sc[1] + c[1], co.z * sc[2] + c[2]))
    return bm


def tubo_curva(pts, r, seg=6):
    """Tubo que sigue una polilínea (chorros de agua, respaldos de hierro)."""
    bm = bmesh.new()
    pts = [Vector(p) for p in pts]
    anillos = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        x = d.cross(ref).normalized()
        y = d.cross(x).normalized()
        rr = r(i / (len(pts) - 1)) if callable(r) else r
        anillos.append([bm.verts.new(p + (x * math.cos(TAU * k / seg) + y * math.sin(TAU * k / seg)) * rr) for k in range(seg)])
    for a, b in zip(anillos, anillos[1:]):
        for k in range(seg):
            j = (k + 1) % seg
            bm.faces.new((a[k], a[j], b[j], b[k]))
    bm.faces.new(list(reversed(anillos[0])))
    bm.faces.new(anillos[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def mover(bm, M):
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    if M.to_3x3().determinant() < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    return bm


def T(x, y, z):
    return Matrix.Translation((x, y, z))


def Rz(a):
    return Matrix.Rotation(a, 4, "Z")


def Rx(a):
    return Matrix.Rotation(a, 4, "X")


def Ry(a):
    return Matrix.Rotation(a, 4, "Y")


# ================================================================= piezas
def fuente():
    """Fuente de plaza de tres pisos: pileta de piedra moldurada (r 1,6, borde a 0,65 m), columna con
    estrías, taza grande festoneada con cortina de agua, taza chica, remate con chorro, y ocho chorros en
    arco desde el borde de la pileta. La colisión (Kit.PARQUE_COL) sigue siendo la de antes."""
    P = Pieza()
    # pileta: zócalo, pared con panza, labio volado y la cara de adentro
    P.add(torno([(1.52, 0.0), (1.56, 0.06), (1.5, 0.1), (1.47, 0.32), (1.5, 0.48), (1.58, 0.53), (1.6, 0.6), (1.55, 0.65),
                 (1.35, 0.65), (1.3, 0.6), (1.28, 0.15)], seg=40, tapas=False), "piedra", 0.0, 0.65, True)
    P.add(torno([(1.31, 0.62), (1.53, 0.63), (1.53, 0.655), (1.31, 0.655), (1.31, 0.62)], seg=40, tapas=False), "lajas", 0.6, 0.66, True)
    # fondo y agua de la pileta
    P.add(torno([(1.29, 0.0), (1.29, 0.14), (0.0, 0.14)], seg=40), "piedra_osc", 0.0, 0.14)
    P.add(torno([(1.285, 0.14), (1.285, 0.44), (0.0, 0.44)], seg=40), "agua", 0.14, 1.9)
    # pedestal con estrías (16) y base cuadrada redondeada
    P.add(torno([(0.34, 0.4), (0.34, 0.52), (0.27, 0.56), (0.24, 0.6)], seg=16, tapas=True), "piedra", 0.4, 0.6, True)
    col = torno([(0.2, 0.58), (0.19, 0.75), (0.17, 0.95), (0.19, 1.02)], seg=32, ondas=(16, 0.07))
    P.add(col, "piedra", 0.5, 1.1, True)
    # cuatro peces (bocas de agua) apoyados en el pedestal, escupiendo a la pileta
    for k in range(4):
        a = TAU * k / 4 + PI / 4
        M = T(math.cos(a) * 0.3, math.sin(a) * 0.3, 0.62) @ Rz(a)
        P.add(mover(bollo((0, 0, 0), 0.08, (1.4, 0.75, 0.75), 1), M), "piedra_osc", 0.55, 0.7, True)
        P.add(mover(bollo((0.11, 0, 0.0), 0.035, (1, 1, 1), 1), M), "piedra_osc", 0.55, 0.7, True)
        arco = [Vector((math.cos(a) * (0.42 + 0.12 * t), math.sin(a) * (0.42 + 0.12 * t), 0.63 + 0.08 * math.sin(t * PI) - 0.2 * t * t))
                for t in [i / 6 for i in range(7)]]
        P.add(tubo_curva(arco, lambda t: 0.022 * (1 - 0.4 * t), 6), "agua", 0.4, 1.9, True)
    # taza grande festoneada (12 lóbulos) con borde y agua adentro
    P.add(torno([(0.18, 1.0), (0.45, 1.06), (0.68, 1.16), (0.74, 1.24), (0.7, 1.27), (0.62, 1.2), (0.2, 1.14)], seg=48,
                ondas=(12, 0.045)), "piedra", 1.0, 1.27, True)
    P.add(torno([(0.64, 1.2), (0.64, 1.23), (0.0, 1.23)], seg=48, ondas=(12, 0.045)), "agua", 0.4, 1.9)
    # de cada festón cae un chorrito a la pileta
    for k in range(12):
        a = TAU * k / 12
        pts = []
        for i in range(7):
            t = i / 6
            r = 0.77 + 0.2 * t
            pts.append(Vector((math.cos(a) * r, math.sin(a) * r, 1.24 + 0.03 * math.sin(t * PI) - 0.8 * t * t)))
        P.add(tubo_curva(pts, lambda t: 0.018 + 0.01 * t, 6), "agua", 0.4, 1.9, True)
        P.add(bollo((math.cos(a) * 0.97, math.sin(a) * 0.97, 0.45), 0.05, (1, 1, 0.35), 1), "agua", 0.4, 1.9, True)
    # fuste alto, taza chica y remate (piña) con chorro
    P.add(torno([(0.12, 1.2), (0.09, 1.3), (0.08, 1.5), (0.11, 1.55)], seg=16), "piedra", 1.2, 1.6, True)
    P.add(torno([(0.08, 1.52), (0.26, 1.58), (0.36, 1.65), (0.33, 1.68), (0.08, 1.62)], seg=32, ondas=(8, 0.05)), "piedra", 1.5, 1.7, True)
    P.add(torno([(0.3, 1.64), (0.3, 1.665), (0.0, 1.665)], seg=32), "agua", 0.4, 1.9)
    P.add(torno([(0.07, 1.64), (0.09, 1.7), (0.07, 1.78), (0.03, 1.84), (0.0, 1.86)], seg=12), "piedra", 1.6, 1.86, True)
    P.add(torno([(0.025, 1.84), (0.04, 1.92), (0.03, 1.98), (0.0, 2.0)], seg=10), "agua", 0.4, 1.9, True)
    # ocho chorros en arco desde el borde de la pileta hacia el centro
    for k in range(8):
        a = TAU * k / 8 + PI / 8
        q0 = Vector((math.cos(a) * 1.3, math.sin(a) * 1.3, 0.62))
        q1 = Vector((math.cos(a) * 0.62, math.sin(a) * 0.62, 0.44))
        pts = []
        for i in range(9):
            t = i / 8
            p = q0.lerp(q1, t)
            p.z += math.sin(t * PI) * 0.55
            pts.append(p)
        P.add(tubo_curva(pts, lambda t: 0.012 + 0.008 * t, 6), "agua", 0.4, 1.9, True)
        P.add(bollo((q1.x, q1.y, 0.45), 0.045, (1, 1, 0.35), 1), "agua", 0.4, 1.9, True)
        P.add(cil((q0.x, q0.y, 0.6), (q0.x * 0.98, q0.y * 0.98, 0.665), 0.03, 0.025, 8), "metal", 0.6, 0.67, True)
    return P


def cantero():
    """Cantero redondo de la plaza (r 1,32, alto 0,53): pared de bloques de piedra, coronamiento de laja
    con moldura, tierra a 0,4 m y una guarda de flores y matitas contra el borde (el árbol y los
    arbustos del medio los pone la loseta)."""
    P = Pieza()
    rng = random.Random(5)
    n = 18
    for k in range(n):   # bloques con juntas
        a0 = TAU * k / n + 0.006
        a1 = TAU * (k + 1) / n - 0.006
        bm = bmesh.new()
        anillos = []
        for (r, z) in ((1.25, 0.0), (1.26, 0.42), (1.06, 0.42), (1.06, 0.0)):
            anillos.append([bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for a in (a0 + (a1 - a0) * i / 3 for i in range(4))])
        for i in range(4):
            a, b = anillos[i], anillos[(i + 1) % 4]
            for j in range(3):
                bm.faces.new((a[j], a[j + 1], b[j + 1], b[j]))
        for idx in (0, 3):
            pass
        bm.faces.new((anillos[0][0], anillos[1][0], anillos[2][0], anillos[3][0]))
        bm.faces.new((anillos[3][3], anillos[2][3], anillos[1][3], anillos[0][3]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        P.add(bm, "piedra" if k % 3 else "piedra_osc", 0.0, 0.45)
    P.add(torno([(1.27, 0.0), (1.27, 0.03), (1.05, 0.03), (1.05, 0.0), (1.27, 0.0)], seg=36, tapas=False), "piedra_osc", 0.0, 0.05)
    P.add(torno([(1.0, 0.42), (1.3, 0.42), (1.32, 0.46), (1.3, 0.53), (1.0, 0.53), (0.98, 0.48), (1.0, 0.42)], seg=48, tapas=False),
          "lajas", 0.42, 0.53, True)
    P.add(torno([(1.0, 0.0), (1.0, 0.4), (0.0, 0.41)], seg=36), "tierra", 0.2, 0.41)
    # guarda de flores entre r 0,72 y 0,95 (el centro queda libre para el árbol y los arbustos)
    colores = ["flor_rosa", "flor_amarilla", "flor_violeta", "flor_blanca", "flor_roja"]
    for k in range(22):
        a = TAU * k / 22 + rng.uniform(-0.05, 0.05)
        r = rng.uniform(0.78, 0.92)
        c = Vector((r * math.cos(a), r * math.sin(a), 0.41))
        P.add(bollo(c + Vector((0, 0, 0.05)), 0.09, (1, 1, 0.75), 1, 0.15, rng), "hoja" if k % 2 else "hoja_osc", 0.4, 0.6)
        col = colores[(k // 2) % len(colores)]
        for j in range(3):
            d = Vector((rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06), 0.13 + rng.uniform(0, 0.04)))
            P.add(bollo(c + d, 0.032, (1, 1, 0.7), 1), col, 0.4, 0.6)
    # matas de pasto alto entre las flores
    for k in range(10):
        a = TAU * (k + 0.5) / 10
        c = Vector((0.66 * math.cos(a), 0.66 * math.sin(a), 0.41))
        for j in range(4):
            b = rng.uniform(0, TAU)
            P.add(cil(c, c + Vector((math.cos(b) * 0.07, math.sin(b) * 0.07, 0.2)), 0.02, 0.003, 4), "pasto_claro", 0.4, 0.62)
    return P


def mesa_cafe(tela):
    """Mesa de café porteña: tapa de mármol blanca con canto, pie de hierro con tres patas, dos sillas
    de bistró (asiento de madera, respaldo curvo de hierro), un cortado y la azucarera, y sombrilla de
    12 gajos con faldón festoneado. Misma huella (1,35 m) y alto (2,45 m) que antes."""
    P = Pieza()
    # mesa
    P.add(torno([(0.38, 0.72), (0.4, 0.735), (0.4, 0.755), (0.38, 0.765), (0.0, 0.765)], seg=32), "blanco", 0.7, 0.77, True)
    P.add(torno([(0.36, 0.7), (0.37, 0.72), (0.0, 0.72)], seg=24), "piedra", 0.7, 0.73, True)
    P.add(torno([(0.045, 0.06), (0.03, 0.15), (0.028, 0.6), (0.04, 0.66), (0.09, 0.71), (0.0, 0.71)], seg=12), "hierro", 0.0, 0.72, True)
    for k in range(3):
        a = TAU * k / 3 + PI / 6
        pts = [Vector((math.cos(a) * 0.04, math.sin(a) * 0.04, 0.12)), Vector((math.cos(a) * 0.17, math.sin(a) * 0.17, 0.05)),
               Vector((math.cos(a) * 0.27, math.sin(a) * 0.27, 0.02)), Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.035))]
        P.add(tubo_curva(pts, 0.018, 6), "hierro", 0.0, 0.2, True)
    # sobre la mesa: cortado con plato, vaso de soda y azucarera
    P.add(torno([(0.06, 0.765), (0.065, 0.772), (0.0, 0.772)], seg=16), "blanco", 0.76, 0.78)
    P.add(torno([(0.028, 0.772), (0.036, 0.82), (0.0, 0.81)], seg=14), "blanco", 0.76, 0.83, True)
    P.add(torno([(0.031, 0.814), (0.031, 0.818), (0.0, 0.818)], seg=14), "madera_osc", 0.8, 0.82)
    P.add(torno([(0.026, 0.765), (0.03, 0.87), (0.0, 0.86)], seg=12), "vidrio", 0.76, 0.88, True)
    P.add(torno([(0.03, 0.765), (0.035, 0.81), (0.022, 0.83), (0.0, 0.84)], seg=12, cx=-0.12, cy=0.1), "plastico_rojo"
          if tela == "toldo_rojo" else "plastico_verde", 0.76, 0.85, True)
    # sillas de bistró a los costados (miran a la mesa)
    for s in (-1, 1):
        x = s * 0.72
        M = T(x, 0, 0) @ Rz(0 if s < 0 else PI)
        P.add(mover(torno([(0.2, 0.44), (0.21, 0.455), (0.2, 0.475), (0.0, 0.475)], seg=20), M), "madera", 0.43, 0.48, True)
        for dx, dy in ((0.13, 0.13), (0.13, -0.13), (-0.13, 0.13), (-0.13, -0.13)):
            sx = 1.15 if dx < 0 else 1.0
            P.add(mover(cil((dx, dy, 0.44), (dx * 1.25 * sx, dy * 1.25, 0.0), 0.012, 0.012, 5), M), "hierro", 0.0, 0.45)
        P.add(mover(torno([(0.15, 0.2), (0.155, 0.215), (0.15, 0.23)], seg=16, tapas=False), M), "hierro", 0.0, 0.45)
        # respaldo curvo (del lado de afuera: -X en el marco de la silla)
        pts = [Vector((-0.17 + 0.03 * math.cos(b) * 0, 0.17 * math.sin(b) * 1.0, 0.47)) for b in []]
        arco = []
        for i in range(9):
            b = -PI / 2 + PI * i / 8
            arco.append(Vector((-0.12 - 0.07 * math.cos(b), 0.17 * math.sin(b), 0.86 - 0.03 * math.cos(b) * 0)))
        P.add(mover(tubo_curva(arco, 0.016, 6), M), "hierro", 0.4, 0.9, True)
        for i in (0, 4, 8):
            q = arco[i]
            P.add(mover(cil((q.x * 0.92, q.y * 0.95, 0.47), (q.x, q.y, 0.86), 0.012, 0.012, 5), M), "hierro", 0.4, 0.9)
        P.add(mover(tubo_curva([Vector((-0.17, -0.12, 0.66)), Vector((-0.2, 0.0, 0.67)), Vector((-0.17, 0.12, 0.66))], 0.012, 5), M),
              "hierro", 0.4, 0.9, True)
    # sombrilla: palo, gajos alternados, faldón festoneado y remate
    P.add(cil((0, 0, 0.77), (0, 0, 2.47), 0.022, 0.022, 8), "madera", 0.7, 2.5, True)
    P.add(torno([(0.035, 2.0), (0.04, 2.06), (0.0, 2.08)], seg=10), "madera_osc", 2.0, 2.1, True)
    n = 12
    for k in range(n):
        a0, a1 = TAU * k / n, TAU * (k + 1) / n
        color = "sombrilla_crema" if k % 2 == 0 else tela
        bm = bmesh.new()
        punta = bm.verts.new((0, 0, 2.47))
        filas = []
        for (r, z) in ((0.45, 2.38), (0.9, 2.24), (1.32, 2.06)):
            filas.append([bm.verts.new((r * math.cos(a0 + (a1 - a0) * i / 3) * (1 - 0.03 * math.sin(PI * i / 3)),
                                        r * math.sin(a0 + (a1 - a0) * i / 3) * (1 - 0.03 * math.sin(PI * i / 3)), z + 0.02 * math.sin(PI * i / 3)))
                          for i in range(4)])
        for i in range(3):
            bm.faces.new((punta, filas[0][i], filas[0][i + 1]))
        for f in range(2):
            for i in range(3):
                bm.faces.new((filas[f][i], filas[f + 1][i], filas[f + 1][i + 1], filas[f][i + 1]))
        # faldón: dos ondas por gajo
        bajo = []
        for i in range(4):
            q = filas[2][i].co
            bajo.append(bm.verts.new((q.x * 1.005, q.y * 1.005, q.z - 0.1 + (0.04 if i in (0, 3) else 0.0))))
        for i in range(3):
            bm.faces.new((filas[2][i], bajo[i], bajo[i + 1], filas[2][i + 1]))
        dup = bmesh.ops.duplicate(bm, geom=list(bm.faces))
        nuevas = [g for g in dup["geom"] if isinstance(g, bmesh.types.BMFace)]
        bmesh.ops.reverse_faces(bm, faces=nuevas)
        P.add(bm, color, 1.9, 2.47)
        # varilla
        P.add(cil((0, 0, 2.0), (math.cos(a0) * 1.25, math.sin(a0) * 1.25, 2.06), 0.007, 0.007, 4), "metal", 2.0, 2.1)
    P.add(torno([(0.05, 2.46), (0.05, 2.5), (0.03, 2.53), (0.0, 2.55)], seg=10), tela, 2.4, 2.55, True)
    return P


def maceton(flores):
    """Macetón de hormigón cuadrado (1 x 1 m) con borde moldurado y patitas, tierra y, según el caso, un
    arbusto podado en bola o una mata de geranios con flores rojas y rosas que cuelgan por el borde."""
    P = Pieza()
    rng = random.Random(42 if flores else 41)
    P.add(caja(0.98, 0.98, 0.06, 0, 0, 0.04, bisel=0.015), "piedra_osc", 0.0, 0.1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add(caja(0.16, 0.16, 0.05, sx * 0.38, sy * 0.38, 0.0, bisel=0.01), "piedra_osc", 0.0, 0.06)
    P.add(caja(0.92, 0.92, 0.5, 0, 0, 0.09, bisel=0.02), "blanco", 0.0, 0.66)
    # paneles hundidos en las cuatro caras
    for k in range(4):
        M = Rz(k * PI / 2)
        P.add(mover(caja(0.66, 0.02, 0.3, 0, -0.462, 0.19, bisel=0.006), M), "piedra", 0.1, 0.6)
    P.add(caja(1.04, 1.04, 0.07, 0, 0, 0.58, bisel=0.02), "lajas", 0.5, 0.66)
    P.add(caja(0.86, 0.86, 0.02, 0, 0, 0.635), "tierra", 0.5, 0.66)
    if not flores:
        # boj podado: una bola grande y facetada sobre un tronquito
        P.add(cil((0, 0, 0.62), (0, 0, 0.82), 0.05, 0.04, 6), "tronco", 0.6, 0.85)
        P.add(bollo((0, 0, 1.08), 0.42, (1, 1, 0.98), 2, 0.06, rng), "hoja_osc", 0.68, 1.53)
        for k in range(6):
            a = TAU * k / 6 + 0.3
            P.add(bollo((math.cos(a) * 0.28, math.sin(a) * 0.28, 1.12 + 0.12 * math.sin(3 * a)), 0.17, (1, 1, 0.9), 1, 0.1, rng),
                  "hoja", 0.68, 1.53)
        P.add(bollo((0.05, -0.05, 1.42), 0.12, (1, 1, 0.8), 1, 0.1, rng), "hoja_clara", 0.68, 1.53)
    else:
        # geranios: matas de hojas redondas, flores en ramilletes y ramas que cuelgan
        for k in range(7):
            a = TAU * k / 7
            r = 0.22 if k else 0.0
            c = Vector((math.cos(a) * r, math.sin(a) * r, 0.78 + (0.12 if k == 0 else 0)))
            P.add(bollo(c, 0.2, (1.1, 1.1, 0.8), 1, 0.12, rng), "hoja" if k % 2 else "hoja_osc", 0.62, 1.2)
        for k in range(14):
            a = TAU * k / 14 + rng.uniform(-0.1, 0.1)
            r = rng.uniform(0.1, 0.36)
            c = Vector((math.cos(a) * r, math.sin(a) * r, 0.9 + 0.12 * (1 - r / 0.36) + rng.uniform(0, 0.05)))
            col = "flor_roja" if k % 3 else "flor_rosa"
            for j in range(5):
                d = Vector((rng.uniform(-0.045, 0.045), rng.uniform(-0.045, 0.045), rng.uniform(0, 0.035)))
                P.add(bollo(c + d, 0.032, (1, 1, 0.8), 1), col, 0.85, 1.15)
        for k in range(8):   # ramas que cuelgan sobre el borde
            a = TAU * k / 8 + 0.2
            lado = Vector((math.cos(a), math.sin(a), 0))
            pts = [lado * 0.3 + Vector((0, 0, 0.72)), lado * 0.5 + Vector((0, 0, 0.7)), lado * 0.56 + Vector((0, 0, 0.58)),
                   lado * 0.58 + Vector((0, 0, 0.45))]
            P.add(tubo_curva(pts, 0.012, 4), "hoja_osc", 0.4, 0.8, True)
            for j, t in enumerate((0.55, 0.85)):
                q = pts[1].lerp(pts[3], t)
                P.add(bollo(q + lado * 0.03, 0.045, (1, 1, 0.8), 1, 0.1, rng), "hoja", 0.4, 0.8)
            if k % 2 == 0:
                P.add(bollo(pts[2] + lado * 0.05, 0.03, (1, 1, 0.8), 1), "flor_roja", 0.4, 0.8)
    return P


PIEZAS = {
    "fuente": fuente, "cantero": cantero,
    "mesa_cafe_roja": lambda: mesa_cafe("toldo_rojo"), "mesa_cafe_verde": lambda: mesa_cafe("toldo_verde"),
    "maceton": lambda: maceton(False), "maceton_flores": lambda: maceton(True),
}


# ================================================================= salida
def a_objeto(P, nombre):
    out = bmesh.new()
    uvl = out.loops.layers.uv.new("UVMap")
    for (bm, color, z0, z1, suave) in P.partes:
        zs = [v.co.z for v in bm.verts]
        lo = min(zs) if z0 is None else z0
        hi = max(zs) if z1 is None else z1
        span = max(hi - lo, 1e-4)
        mapa = {}
        for v in bm.verts:
            mapa[v] = out.verts.new(v.co)
        for f in bm.faces:
            try:
                nf = out.faces.new([mapa[v] for v in f.verts])
            except ValueError:
                continue
            nf.smooth = suave
            for l, nl in zip(f.loops, nf.loops):
                nl[uvl].uv = paleta.uv(color, (l.vert.co.z - lo) / span)
        bm.free()
    me = bpy.data.meshes.new(nombre)
    out.to_mesh(me)
    tris = sum(len(f.verts) - 2 for f in out.faces)
    out.free()
    ob = bpy.data.objects.new(nombre, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob, tris


def limpiar():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)


def exportar(nombre):
    limpiar()
    ob, tris = a_objeto(PIEZAS[nombre](), nombre)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    ruta = os.path.join(ROOT, SALIDAS[nombre])
    bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                              export_materials="NONE", export_cameras=False, export_lights=False)
    d = ob.dimensions
    return tris, d


def render_todas(carpeta):
    """Vista previa de todas las piezas juntas, con la paleta de verdad."""
    limpiar()
    img = paleta.imagen(bpy, "paleta_vista", carpeta)
    mat = bpy.data.materials.new("vista")
    mat.use_nodes = True
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
    lugares = {"fuente": (0, 0), "cantero": (3.6, 0), "mesa_cafe_roja": (-3.2, -0.5), "mesa_cafe_verde": (-3.2, 2.6),
               "maceton": (3.4, 2.6), "maceton_flores": (5.0, 2.6)}
    for n, (x, y) in lugares.items():
        ob, _ = a_objeto(PIEZAS[n](), n)
        ob.location = (x, y, 0)
        ob.data.materials.append(mat)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    w = sc.world = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.88, 0.95, 1)
    bpy.ops.mesh.primitive_plane_add(size=40)
    pm = bpy.data.materials.new("piso")
    pm.use_nodes = True
    pm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.7, 0.66, 0.58, 1)
    bpy.context.object.data.materials.append(pm)
    sol = bpy.data.objects.new("sol", bpy.data.lights.new("sol", "SUN"))
    sol.data.energy = 3.5
    sol.rotation_euler = (math.radians(50), 0, math.radians(30))
    sc.collection.objects.link(sol)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    for nombre, loc, rot, lens in (("props_todas", (0.6, -10.5, 5.0), (62, 0, 0), 32),
                                   ("props_fuente", (2.4, -3.6, 2.4), (68, 0, 33), 35),
                                   ("props_mesa", (-1.6, -3.4, 2.1), (70, 0, -25), 35),
                                   ("props_cantero_macetones", (4.2, -2.6, 2.2), (65, 0, 5), 30)):
        cam.location = loc
        cam.rotation_euler = [math.radians(a) for a in rot]
        cam.data.lens = lens
        sc.render.resolution_x, sc.render.resolution_y = 1400, 900
        sc.render.filepath = os.path.join(carpeta, nombre + ".png")
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for n in (SOLO or list(PIEZAS.keys())):
        tris, d = exportar(n)
        print("OK %-16s %5d tris  %.2f x %.2f x %.2f m" % (n, tris, d.x, d.y, d.z))
    if RENDER:
        os.makedirs(RENDER, exist_ok=True)
        render_todas(RENDER)
