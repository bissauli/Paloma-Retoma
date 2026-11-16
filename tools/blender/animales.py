# Perros y gatos con esqueleto y animaciones (mapa V3.1). Antes eran piezas fijas del kit de la
# ciudad que sólo daban saltitos; ahora cada uno es un GLB con la malla pegada a sus huesos y las
# animaciones hechas acá con keyframes, como la paloma.
#
# Uso (sin abrir Blender):
#   F:/blender.exe -b --factory-startup -P tools/blender/animales.py -- [--previa]
#
# Salida: modelos/animales/<nombre>.glb (perro_marron, perro_negro, perro_blanco, perro_bolt,
#   gato_naranja, gato_negro, gato_gris). Con --previa, además, una hoja de cuadros por especie en
#   modelos/animales/previas/ (Godot la ignora).
#
# Mismo estilo que el kit (bollos facetados, sin bisel) y la misma paleta (paleta.py): los GLB salen
# sin material y Godot les pone el del kit (Kit.material()). Las medidas son las del perro "parado"
# del kit viejo; el gato se arma con las mismas proporciones de perro y Godot lo achica (ver
# world/animal.gd).
#
# Convenciones: el animal mira hacia -Y (+Z en Godot), con el origen entre las patas, a nivel del
# piso. Las poses se escriben en grados y en los ejes de la armadura (ver _rotacion): "cabeceo" en X
# (+ baja la nariz, lleva una pata hacia atrás o levanta la cola), "giro" en Z (+ hacia la izquierda
# del animal, que es +X) y "rolido" en Y. Las patas .L están del lado +X (la izquierda del animal).

import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector, Matrix, Quaternion

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "modelos", "animales")
DIR_PREVIAS = os.path.join(OUT, "previas")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIA = "--previa" in args
os.makedirs(OUT, exist_ok=True)
if PREVIA:
    os.makedirs(DIR_PREVIAS, exist_ok=True)
    open(os.path.join(DIR_PREVIAS, ".gdignore"), "w").close()

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paleta  # noqa: E402

bpy.ops.wm.read_factory_settings(use_empty=True)
SCENE = bpy.context.scene
SCENE.render.fps = 30

# ---------------------------------------------------------------- geometría (como en generar_ciudad.py)


def bm_box(sx, sy, sz, x=0, y=0, z=0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx + x, v.co.y * sy + y, v.co.z * sz + z + sz / 2))
    return bm


def bm_cyl(p0, p1, r0, r1=None, seg=8):
    r1 = r0 if r1 is None else r1
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    L = d.length
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r0, radius2=r1, depth=L)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    M = Matrix.Translation(p0) @ rot @ Matrix.Translation((0, 0, L / 2))
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm


def bm_blob(c, r, sc=(1, 1, 1), sub=1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    for v in bm.verts:
        v.co = Vector((v.co.x * sc[0] + c[0], v.co.y * sc[1] + c[1], v.co.z * sc[2] + c[2]))
    return bm


def bm_prisma(pts, z0, z1):
    bm = bmesh.new()
    abajo = [bm.verts.new((x, y, z0)) for x, y in pts]
    arriba = [bm.verts.new((x, y, z1)) for x, y in pts]
    bm.faces.new(list(reversed(abajo)))
    bm.faces.new(arriba)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((abajo[i], abajo[j], arriba[j], arriba[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def P(bm, color, z0=None, z1=None):
    """Pinta con el degradé del color (abajo oscuro, arriba claro), como el kit."""
    uvl = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    zs = [v.co.z for v in bm.verts]
    lo = min(zs) if z0 is None else z0
    hi = max(zs) if z1 is None else z1
    span = max(hi - lo, 1e-4)
    for f in bm.faces:
        for l in f.loops:
            l[uvl].uv = paleta.uv(color, (l.vert.co.z - lo) / span)
    return bm


def _activar(objs):
    for o in bpy.context.view_layer.objects:
        if o:
            o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def suave(a, b, t):
    t = min(max((t - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- esqueletos
# (nombre, cabeza del hueso, cola del hueso, padre). Las patas se doblan en el codo/rodilla (mitad).


def _patas(x, y_del, y_tra, alto):
    m = alto / 2
    out = []
    for lado, s in (("L", 1), ("R", -1)):
        out += [("brazo." + lado, (s * x, y_del, alto), (s * x, y_del, m), "pecho"),
                ("mano." + lado, (s * x, y_del, m), (s * x, y_del, 0.0), "brazo." + lado),
                ("muslo." + lado, (s * x, y_tra, alto), (s * x, y_tra, m), "cadera"),
                ("pie." + lado, (s * x, y_tra, m), (s * x, y_tra, 0.0), "muslo." + lado)]
    return out


HUESOS_PERRO = [
    ("raiz", (0, 0, 0), (0, 0, 0.25), None),
    ("cadera", (0, 0.3, 0.46), (0, 0.0, 0.48), "raiz"),
    ("pecho", (0, 0.0, 0.48), (0, -0.3, 0.52), "cadera"),
    ("cuello", (0, -0.3, 0.52), (0, -0.4, 0.62), "pecho"),
    ("cabeza", (0, -0.4, 0.62), (0, -0.62, 0.66), "cuello"),
    ("oreja.L", (0.1, -0.4, 0.76), (0.14, -0.38, 0.62), "cabeza"),
    ("oreja.R", (-0.1, -0.4, 0.76), (-0.14, -0.38, 0.62), "cabeza"),
    ("cola.1", (0, 0.37, 0.52), (0, 0.46, 0.64), "cadera"),
    ("cola.2", (0, 0.46, 0.64), (0, 0.54, 0.78), "cola.1"),
] + _patas(0.11, -0.22, 0.28, 0.44)

HUESOS_GATO = [
    ("raiz", (0, 0, 0), (0, 0, 0.25), None),
    ("cadera", (0, 0.3, 0.42), (0, 0.0, 0.43), "raiz"),
    ("pecho", (0, 0.0, 0.43), (0, -0.28, 0.45), "cadera"),
    ("cuello", (0, -0.28, 0.45), (0, -0.36, 0.56), "pecho"),
    ("cabeza", (0, -0.36, 0.56), (0, -0.56, 0.6), "cuello"),
    ("oreja.L", (0.08, -0.39, 0.71), (0.1, -0.41, 0.86), "cabeza"),
    ("oreja.R", (-0.08, -0.39, 0.71), (-0.1, -0.41, 0.86), "cabeza"),
    ("cola.1", (0, 0.35, 0.45), (0, 0.45, 0.58), "cadera"),
    ("cola.2", (0, 0.45, 0.58), (0, 0.5, 0.76), "cola.1"),
    ("cola.3", (0, 0.5, 0.76), (0, 0.47, 0.92), "cola.2"),
] + _patas(0.09, -0.2, 0.26, 0.4)


def _cuerpo_partido(y_corte, ancho=0.08):
    """Pesos del cuerpo: atrás de y_corte va con la cadera, adelante con el pecho, y en el medio se
    mezclan (así el lomo se dobla sin cortarse)."""
    def pesos(co):
        w = suave(y_corte - ancho, y_corte + ancho, co.y)
        return {"cadera": w, "pecho": 1.0 - w}
    return pesos


# ---------------------------------------------------------------- mallas


def partes_perro(color, color2, bolt=False):
    out = [(P(bm_blob((0, 0.05, 0.45), 0.24, (0.8, 1.45, 0.8), 2), color), _cuerpo_partido(0.0)),
           (P(bm_blob((0, -0.2, 0.5), 0.2, (0.9, 1, 0.95), 2), color), "pecho"),
           (P(bm_cyl((0, -0.29, 0.5), (0, -0.4, 0.64), 0.12, 0.1, 6), color), "cuello"),
           (P(bm_blob((0, -0.42, 0.68), 0.16, (1, 1.05, 1), 2), color), "cabeza"),
           (P(bm_box(0.13, 0.17, 0.11, 0, -0.58, 0.6), color2), "cabeza"),
           (P(bm_box(0.06, 0.04, 0.05, 0, -0.68, 0.64), "hierro"), "cabeza"),
           (P(bm_cyl((0, 0.36, 0.51), (0, 0.46, 0.64), 0.042, 0.032, 5), color), "cola.1"),
           (P(bm_cyl((0, 0.46, 0.64), (0, 0.55, 0.79), 0.032, 0.018, 5), color), "cola.2")]
    for s, lado in ((1, "L"), (-1, "R")):
        out.append((P(bm_box(0.035, 0.03, 0.035, s * 0.07, -0.55, 0.72), "hierro"), "cabeza"))
        out.append((P(bm_cyl((s * 0.1, -0.4, 0.76), (s * 0.14, -0.38, 0.62), 0.06, 0.03, 4), color2), "oreja." + lado))
        for y, arriba, abajo in ((-0.22, "brazo.", "mano."), (0.28, "muslo.", "pie.")):
            out.append((P(bm_cyl((s * 0.11, y, 0.46), (s * 0.11, y, 0.2), 0.058, 0.048, 6), color), arriba + lado))
            out.append((P(bm_cyl((s * 0.11, y, 0.23), (s * 0.11, y, 0.02), 0.047, 0.042, 6), color), abajo + lado))
            out.append((P(bm_blob((s * 0.11, y - 0.03, 0.035), 0.052, (1, 1.3, 0.7), 1), color), abajo + lado))
    if bolt:
        # El rayo negro en el costado izquierdo (como la pieza vieja de la cucha de Bolt)
        rayo = [(0.0, 0.42), (0.12, 0.42), (0.05, 0.3), (0.16, 0.3), (-0.06, 0.08), (0.0, 0.24), (-0.1, 0.24)]
        bm = bm_prisma([(y * 1.3 - 0.06, z * 0.35) for y, z in rayo], 0.1, 0.205)
        R = Matrix.Translation((0, 0.0, 0.38)) @ Matrix.Rotation(math.radians(90), 4, "Y") @ Matrix.Rotation(math.radians(90), 4, "Z")
        bmesh.ops.transform(bm, matrix=R, verts=bm.verts)
        out.append((P(bm, "hierro"), _cuerpo_partido(0.0)))
    return out


def partes_gato(color, color2):
    out = [(P(bm_blob((0, 0.04, 0.42), 0.22, (0.72, 1.5, 0.72), 2), color), _cuerpo_partido(0.0)),
           (P(bm_blob((0, -0.18, 0.45), 0.17, (0.85, 1, 0.95), 2), color), "pecho"),
           (P(bm_cyl((0, -0.27, 0.45), (0, -0.37, 0.58), 0.095, 0.085, 6), color), "cuello"),
           (P(bm_blob((0, -0.4, 0.62), 0.15, (1.05, 1, 0.95), 2), color), "cabeza"),
           (P(bm_box(0.12, 0.08, 0.08, 0, -0.53, 0.54), color2), "cabeza"),
           (P(bm_box(0.05, 0.03, 0.035, 0, -0.575, 0.6), "flor_rosa"), "cabeza"),
           (P(bm_cyl((0, 0.34, 0.44), (0, 0.45, 0.58), 0.04, 0.034, 5), color), "cola.1"),
           (P(bm_cyl((0, 0.45, 0.58), (0, 0.5, 0.76), 0.034, 0.03, 5), color), "cola.2"),
           (P(bm_cyl((0, 0.5, 0.76), (0, 0.47, 0.93), 0.03, 0.018, 5), color), "cola.3")]
    for s, lado in ((1, "L"), (-1, "R")):
        out.append((P(bm_box(0.045, 0.03, 0.045, s * 0.065, -0.535, 0.64), "hierro"), "cabeza"))
        out.append((P(bm_cyl((s * 0.08, -0.39, 0.7), (s * 0.1, -0.41, 0.87), 0.065, 0.0, 4), color), "oreja." + lado))
        for y, arriba, abajo in ((-0.2, "brazo.", "mano."), (0.26, "muslo.", "pie.")):
            out.append((P(bm_cyl((s * 0.09, y, 0.42), (s * 0.09, y, 0.18), 0.048, 0.04, 6), color), arriba + lado))
            out.append((P(bm_cyl((s * 0.09, y, 0.21), (s * 0.09, y, 0.02), 0.04, 0.036, 6), color), abajo + lado))
            out.append((P(bm_blob((s * 0.09, y - 0.025, 0.03), 0.045, (1, 1.25, 0.7), 1), color2 if y < 0 else color), abajo + lado))
    return out


# ---------------------------------------------------------------- armado


def armadura(nombre, huesos):
    ad = bpy.data.armatures.new(nombre + "_esqueleto")
    arm = bpy.data.objects.new(nombre + "_esqueleto", ad)
    SCENE.collection.objects.link(arm)
    _activar([arm])
    bpy.ops.object.mode_set(mode="EDIT")
    for n, h, t, padre in huesos:
        eb = ad.edit_bones.new(n)
        eb.head = h
        eb.tail = t
        eb.roll = 0.0
        if padre:
            eb.parent = ad.edit_bones[padre]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


def malla(nombre, partes, arm):
    objs = []
    for bm, grupo in partes:
        me = bpy.data.meshes.new("parte")
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new("parte", me)
        SCENE.collection.objects.link(o)
        for p in me.polygons:
            p.use_smooth = False
        if isinstance(grupo, str):
            o.vertex_groups.new(name=grupo).add(list(range(len(me.vertices))), 1.0, "REPLACE")
        else:
            for v in me.vertices:
                for hueso, w in grupo(v.co).items():
                    if w > 0.0:
                        vg = o.vertex_groups.get(hueso) or o.vertex_groups.new(name=hueso)
                        vg.add([v.index], w, "REPLACE")
        objs.append(o)
    _activar(objs)
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = nombre
    o.data.name = nombre
    o.parent = arm
    mod = o.modifiers.new("esqueleto", "ARMATURE")
    mod.object = arm
    return o


# ---------------------------------------------------------------- animaciones


def _rotacion(pb, cabeceo=0.0, giro=0.0, rolido=0.0):
    """Rotación del hueso escrita en los ejes de la armadura (grados), pasada a su espacio local."""
    q = (Quaternion((0, 0, 1), math.radians(giro)) @ Quaternion((1, 0, 0), math.radians(cabeceo))
         @ Quaternion((0, 1, 0), math.radians(rolido)))
    r = pb.bone.matrix_local.to_quaternion()
    return r.inverted() @ q @ r


def animar(arm, nombre, cuadros, pose, ciclo=True):
    """Graba la animación "nombre" de "cuadros" cuadros (a 30 por segundo). pose(t) con t de 0 a 1
    devuelve {hueso: (cabeceo, giro, rolido)} y, si hace falta, "_alto": cuánto sube o baja el cuerpo
    (en metros). Si es un ciclo, el último cuadro es igual al primero (para que Godot lo repita sin
    saltos)."""
    act = bpy.data.actions.new(nombre)
    arm.animation_data_create()
    arm.animation_data.action = act
    raiz = arm.pose.bones["raiz"]
    r_raiz = raiz.bone.matrix_local.to_quaternion().inverted()
    for f in range(cuadros + 1):
        t = f / cuadros
        p = pose(t % 1.0 if ciclo else t)
        for pb in arm.pose.bones:
            ang = p.get(pb.name, (0.0, 0.0, 0.0))
            pb.rotation_quaternion = _rotacion(pb, *ang)
            pb.keyframe_insert("rotation_quaternion", frame=f)
        raiz.location = r_raiz @ Vector((0.0, p.get("_adelante", 0.0), p.get("_alto", 0.0)))
        raiz.keyframe_insert("location", frame=f)
    pista = arm.animation_data.nla_tracks.new()
    pista.name = nombre
    pista.strips.new(nombre, 0, act)
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()


def mezclar(*poses):
    """Suma poses (los ángulos de cada hueso y el alto se suman)."""
    out = {}
    for p in poses:
        for k, v in p.items():
            if k.startswith("_"):
                out[k] = out.get(k, 0.0) + v
            else:
                a = out.get(k, (0.0, 0.0, 0.0))
                out[k] = (a[0] + v[0], a[1] + v[1], a[2] + v[2])
    return out


def entre(claves, t):
    """Interpola suave entre poses clave [(t, pose), ...] (para las animaciones de una sola vez)."""
    for (t0, p0), (t1, p1) in zip(claves, claves[1:]):
        if t <= t1:
            k = suave(t0, t1, t)
            out = {}
            for n in set(p0) | set(p1):
                if n.startswith("_"):
                    out[n] = p0.get(n, 0.0) * (1 - k) + p1.get(n, 0.0) * k
                else:
                    a = p0.get(n, (0.0, 0.0, 0.0))
                    b = p1.get(n, (0.0, 0.0, 0.0))
                    out[n] = tuple(a[i] * (1 - k) + b[i] * k for i in range(3))
            return out
    return dict(claves[-1][1])


def S(t, veces=1.0, fase=0.0):
    return math.sin(2 * math.pi * (t * veces + fase))


def paso(t, fase, amp, doblez, apoyo):
    """Ángulo de una pata en un ciclo de marcha: apoyada va de adelante (-amp) hacia atrás (+amp) a
    velocidad pareja; en el aire vuelve hacia adelante y se dobla (doblez) para no arrastrar la pata."""
    p = (t + fase) % 1.0
    if p < apoyo:
        return -amp + 2 * amp * p / apoyo, 0.0
    q = (p - apoyo) / (1 - apoyo)
    return amp - 2 * amp * (0.5 - 0.5 * math.cos(math.pi * q)), doblez * math.sin(math.pi * q)


def marcha(t, fases, amp, doblez, apoyo, rebote):
    p = {"_alto": -rebote + rebote * math.cos(4 * math.pi * t)}
    for pata, f in fases.items():
        lado = pata[-1]
        delantera = pata.startswith("brazo")
        a, d = paso(t, f, amp, doblez, apoyo)
        p[pata] = (a, 0, 0)
        p[("mano." if delantera else "pie.") + lado] = (d * (1.0 if delantera else 0.8), 0, 0)
    return p


CAMINAR = {"muslo.L": 0.0, "brazo.L": 0.25, "muslo.R": 0.5, "brazo.R": 0.75}
TROTAR = {"brazo.L": 0.0, "muslo.R": 0.0, "brazo.R": 0.5, "muslo.L": 0.5}

# Poses fijas (se les suma respiración, cola, cabeza...)
SENTADO_PERRO = {"_alto": -0.28, "cadera": (-35, 0, 0), "brazo.L": (35, 0, 0), "brazo.R": (35, 0, 0),
                 "muslo.L": (-25, 6, 0), "muslo.R": (-25, -6, 0), "pie.L": (150, 0, 0), "pie.R": (150, 0, 0),
                 "cuello": (22, 0, 0), "cabeza": (8, 0, 0), "cola.1": (-55, 0, 0), "cola.2": (-15, 0, 0)}
ECHADO_PERRO = {"_alto": -0.26, "brazo.L": (-60, 4, 0), "brazo.R": (-60, -4, 0), "mano.L": (-30, 0, 0),
                "mano.R": (-30, 0, 0), "muslo.L": (-75, 18, 0), "muslo.R": (-75, -18, 0), "pie.L": (150, 0, 0),
                "pie.R": (150, 0, 0), "cuello": (-6, 0, 0), "cola.1": (-62, 35, 0), "cola.2": (-10, 25, 0)}
SENTADO_GATO = {"_alto": -0.34, "cadera": (-45, 0, 0), "brazo.L": (45, 0, 0), "brazo.R": (45, 0, 0),
                "muslo.L": (-28, 8, 0), "muslo.R": (-28, -8, 0), "pie.L": (155, 0, 0), "pie.R": (155, 0, 0),
                "cuello": (28, 0, 0), "cabeza": (12, 0, 0),
                "cola.1": (-55, 55, 0), "cola.2": (-10, 55, 0), "cola.3": (0, 50, 0)}
ECHADO_GATO = {"_alto": -0.26, "brazo.L": (-70, 0, 0), "brazo.R": (-70, 0, 0), "mano.L": (-20, 0, 0),
               "mano.R": (-20, 0, 0), "muslo.L": (-78, 15, 0), "muslo.R": (-78, -15, 0), "pie.L": (155, 0, 0),
               "pie.R": (155, 0, 0), "cuello": (-4, 0, 0), "cola.1": (-82, 60, 0), "cola.2": (-12, 45, 0),
               "cola.3": (-5, 40, 0)}
COLA_ARRIBA_GATO = {"cola.1": (55, 0, 0), "cola.2": (25, 0, 0), "cola.3": (-45, 0, 0)}


def animaciones_perro(arm):
    # Parado: respira, mueve la cola y mira para los costados
    animar(arm, "quieto", 60, lambda t: {
        "_alto": 0.004 * S(t, 2), "pecho": (1.2 * S(t, 2), 0, 0),
        "cuello": (2 * S(t, 1, 0.1), 0, 0), "cabeza": (3 * S(t, 1), 16 * S(t, 1), 4 * S(t, 1, 0.25)),
        "oreja.L": (6 * max(0.0, S(t, 2, 0.1)) ** 4, 0, 0), "oreja.R": (6 * max(0.0, S(t, 2, 0.6)) ** 4, 0, 0),
        "cola.1": (12, 22 * S(t, 3), 0), "cola.2": (8, 26 * S(t, 3, -0.12), 0)})
    # Caminar: marcha de cuatro tiempos (0,8 s por ciclo, ~0,85 m/s a escala 1)
    animar(arm, "caminar", 24, lambda t: mezclar(marcha(t, CAMINAR, 26, 45, 0.62, 0.012), {
        "cadera": (0, 2.5 * S(t, 1), 2 * S(t, 1)), "pecho": (0, -2.5 * S(t, 1), 0),
        "cuello": (3 * S(t, 2, 0.1), 0, 0), "cabeza": (-2 * S(t, 2, 0.1), 0, 0),
        "cola.1": (10, 15 * S(t, 1), 0), "cola.2": (5, 18 * S(t, 1, -0.1), 0),
        "oreja.L": (5 * S(t, 2, 0.2), 0, 0), "oreja.R": (5 * S(t, 2, 0.2), 0, 0)}))
    # Trotar: diagonales juntas (0,53 s por ciclo, ~2 m/s a escala 1)
    animar(arm, "trotar", 16, lambda t: mezclar(marcha(t, TROTAR, 34, 65, 0.45, 0.028), {
        "cadera": (2 * S(t, 2, 0.15), 0, 0), "cuello": (-6 + 5 * S(t, 2, 0.2), 0, 0), "cabeza": (4, 0, 0),
        "cola.1": (22, 25 * S(t, 2), 0), "cola.2": (10, 30 * S(t, 2, -0.1), 0),
        "oreja.L": (-14 + 14 * S(t, 2, 0.3), 0, 0), "oreja.R": (-14 + 14 * S(t, 2, 0.3), 0, 0)}))
    # Olfatear: la nariz al piso, moviéndola de un lado al otro
    animar(arm, "olfatear", 60, lambda t: {
        "_alto": -0.02, "brazo.L": (-6, 0, 0), "brazo.R": (-6, 0, 0), "mano.L": (6, 0, 0), "mano.R": (6, 0, 0),
        "cuello": (42, 0, 0), "cabeza": (30 + 4 * S(t, 6), 15 * S(t, 1), 0),
        "oreja.L": (14, 0, 0), "oreja.R": (14, 0, 0), "cola.1": (16, 18 * S(t, 2), 0), "cola.2": (6, 20 * S(t, 2, -0.1), 0)})
    # Sentado: respira, barre el piso con la cola y mira alrededor
    animar(arm, "sentado", 90, lambda t: mezclar(SENTADO_PERRO, {
        "pecho": (1.2 * S(t, 2), 0, 0), "cabeza": (0, 22 * S(t, 1), 8 * suave(0.55, 0.65, t) * (1 - suave(0.8, 0.9, t))),
        "cola.1": (0, 25 * S(t, 3), 0), "cola.2": (0, 20 * S(t, 3, -0.1), 0)}))
    # Echado con la cabeza levantada (respira despacio)
    animar(arm, "echado", 90, lambda t: mezclar(ECHADO_PERRO, {
        "pecho": (1.5 * S(t, 2), 0, 0), "cadera": (0, 0, 1.5 * S(t, 2)), "cabeza": (0, 18 * S(t, 1), 0),
        "oreja.L": (8 * max(0.0, S(t, 1, 0.3)) ** 6, 0, 0), "cola.2": (0, 12 * S(t, 1), 0)}))
    # Durmiendo: echado con la cabeza apoyada sobre las patas
    animar(arm, "dormido", 120, lambda t: mezclar(ECHADO_PERRO, {
        "_alto": -0.01, "pecho": (2.2 * S(t, 2), 0, 0), "cuello": (32, 0, 0), "cabeza": (26, 8, 6),
        "oreja.R": (10 * max(0.0, S(t, 1, 0.7)) ** 8, 0, 0)}))
    # Ladrar: dos ladridos, firme sobre las patas y con la cola parada (una sola vez)
    def ladrar(t):
        g = math.exp(-((t - 0.2) / 0.07) ** 2) + math.exp(-((t - 0.55) / 0.07) ** 2)
        return {"_alto": -0.02 * g, "brazo.L": (-8, 0, 0), "brazo.R": (-8, 0, 0), "cuello": (-10 * g, 0, 0),
                "cabeza": (-14 * g, 0, 0), "oreja.L": (-10 * g, 0, 0), "oreja.R": (-10 * g, 0, 0),
                "cola.1": (35, 10 * S(t, 4), 0), "cola.2": (20, 12 * S(t, 4), 0)}
    animar(arm, "ladrar", 24, ladrar, ciclo=False)
    # Rascarse la oreja con la pata de atrás, sentado
    animar(arm, "rascarse", 15, lambda t: mezclar(SENTADO_PERRO, {
        "muslo.L": (-95 + 14 * S(t, 2), 25, 0), "pie.L": (-20 - 150 + 25 * S(t, 2), 0, 0),
        "cuello": (-8, 18, 14), "cabeza": (0, 12, 16), "oreja.L": (12 * S(t, 2), 0, 0), "cadera": (0, 0, -6)}))
    # Saltar una valla (una sola vez): se agacha, despega, recoge las patas y cae
    agachado = {"_alto": -0.07, "cadera": (5, 0, 0), "brazo.L": (-10, 0, 0), "brazo.R": (-10, 0, 0),
                "mano.L": (20, 0, 0), "mano.R": (20, 0, 0), "muslo.L": (-20, 0, 0), "muslo.R": (-20, 0, 0),
                "pie.L": (35, 0, 0), "pie.R": (35, 0, 0), "cola.1": (15, 0, 0)}
    despegue = {"_alto": 0.08, "cadera": (-20, 0, 0), "brazo.L": (-35, 0, 0), "brazo.R": (-35, 0, 0),
                "mano.L": (95, 0, 0), "mano.R": (95, 0, 0), "muslo.L": (45, 0, 0), "muslo.R": (45, 0, 0),
                "pie.L": (10, 0, 0), "pie.R": (10, 0, 0), "cuello": (-10, 0, 0), "cola.1": (25, 0, 0)}
    arriba = {"_alto": 0.5, "cadera": (0, 0, 0), "brazo.L": (-60, 0, 0), "brazo.R": (-60, 0, 0),
              "mano.L": (105, 0, 0), "mano.R": (105, 0, 0), "muslo.L": (55, 0, 0), "muslo.R": (55, 0, 0),
              "pie.L": (-15, 0, 0), "pie.R": (-15, 0, 0), "cola.1": (25, 0, 0), "oreja.L": (-20, 0, 0),
              "oreja.R": (-20, 0, 0)}
    bajada = {"_alto": 0.22, "cadera": (16, 0, 0), "brazo.L": (-45, 0, 0), "brazo.R": (-45, 0, 0),
              "mano.L": (-10, 0, 0), "mano.R": (-10, 0, 0), "muslo.L": (20, 0, 0), "muslo.R": (20, 0, 0),
              "pie.L": (60, 0, 0), "pie.R": (60, 0, 0), "cuello": (6, 0, 0), "cola.1": (10, 0, 0),
              "oreja.L": (-10, 0, 0), "oreja.R": (-10, 0, 0)}
    llegada = {"_alto": -0.05, "cadera": (5, 0, 0), "brazo.L": (-8, 0, 0), "brazo.R": (-8, 0, 0),
               "mano.L": (12, 0, 0), "mano.R": (12, 0, 0), "muslo.L": (-12, 0, 0), "muslo.R": (-12, 0, 0),
               "pie.L": (30, 0, 0), "pie.R": (30, 0, 0), "oreja.L": (12, 0, 0), "oreja.R": (12, 0, 0)}
    claves = [(0.0, {}), (0.12, agachado), (0.28, despegue), (0.47, arriba), (0.68, bajada), (0.84, llegada), (1.0, {})]
    animar(arm, "saltar", 20, lambda t: entre(claves, t), ciclo=False)


def animaciones_gato(arm):
    animar(arm, "quieto", 60, lambda t: mezclar(COLA_ARRIBA_GATO, {
        "_alto": 0.003 * S(t, 2), "pecho": (1.0 * S(t, 2), 0, 0), "cabeza": (2 * S(t, 1), 14 * S(t, 1), 0),
        "cola.1": (0, 8 * S(t, 1), 0), "cola.2": (0, 10 * S(t, 1, -0.1), 0), "cola.3": (6 * S(t, 2), 12 * S(t, 1, -0.2), 0),
        "oreja.L": (0, 10 * max(0.0, S(t, 1, 0.4)) ** 6, 0)}))
    animar(arm, "caminar", 24, lambda t: mezclar(marcha(t, CAMINAR, 22, 40, 0.62, 0.008), COLA_ARRIBA_GATO, {
        "cadera": (0, 2 * S(t, 1), 1.5 * S(t, 1)), "pecho": (0, -2 * S(t, 1), 0), "cuello": (2 * S(t, 2, 0.1), 0, 0),
        "cola.3": (0, 14 * S(t, 1), 0)}))
    animar(arm, "trotar", 16, lambda t: mezclar(marcha(t, TROTAR, 30, 60, 0.45, 0.02), {
        "cadera": (2 * S(t, 2, 0.15), 0, 0), "cuello": (-6, 0, 0), "cola.1": (25, 0, 0), "cola.2": (10, 0, 0),
        "cola.3": (5 * S(t, 2), 0, 0), "oreja.L": (-18, 0, 0), "oreja.R": (-18, 0, 0)}))
    animar(arm, "sentado", 90, lambda t: mezclar(SENTADO_GATO, {
        "pecho": (1.0 * S(t, 2), 0, 0), "cabeza": (0, 25 * S(t, 1), 6 * S(t, 1, 0.3)),
        "cola.3": (0, 18 * max(0.0, S(t, 2, 0.1)) ** 3, 0), "oreja.R": (0, -12 * max(0.0, S(t, 1, 0.8)) ** 6, 0)}))
    animar(arm, "echado", 90, lambda t: mezclar(ECHADO_GATO, {
        "pecho": (1.4 * S(t, 2), 0, 0), "cabeza": (0, 16 * S(t, 1), 0), "cola.3": (0, 20 * max(0.0, S(t, 2)) ** 3, 0)}))
    animar(arm, "dormido", 120, lambda t: mezclar(ECHADO_GATO, {
        "pecho": (2.0 * S(t, 2), 0, 0), "cuello": (34, -10, 0), "cabeza": (22, -12, 10),
        "cola.1": (0, 15, 0), "cola.2": (0, 25, 0)}))
    # Lamerse una mano, sentado
    animar(arm, "lamerse", 40, lambda t: mezclar(SENTADO_GATO, {
        "brazo.R": (-75, -8, 0), "mano.R": (65 + 8 * S(t, 3), 0, 0), "cuello": (12, -12, 0),
        "cabeza": (24 + 9 * S(t, 3), -14, -8), "oreja.L": (-6, 0, 0)}))
    # Estirarse (una sola vez): adelanta las manos, baja el pecho, levanta la cola y vuelve
    estirado = {"_alto": -0.08, "cadera": (14, 0, 0), "brazo.L": (-62, 0, 0), "brazo.R": (-62, 0, 0),
                "mano.L": (-25, 0, 0), "mano.R": (-25, 0, 0), "muslo.L": (-6, 0, 0), "muslo.R": (-6, 0, 0),
                "cuello": (-26, 0, 0), "cabeza": (-8, 0, 0), "cola.1": (25, 0, 0), "cola.2": (15, 0, 0),
                "cola.3": (-20, 0, 0), "oreja.L": (-14, 0, 0), "oreja.R": (-14, 0, 0)}
    claves = [(0.0, COLA_ARRIBA_GATO), (0.3, estirado), (0.72, dict(estirado, **{"cabeza": (-14, 0, 6)})),
              (1.0, COLA_ARRIBA_GATO)]
    animar(arm, "estirarse", 45, lambda t: entre(claves, t), ciclo=False)


# ---------------------------------------------------------------- exportar

ANIMALES = [
    ("perro_marron", "perro", lambda: partes_perro("perro_marron", "perro_blanco")),
    ("perro_negro", "perro", lambda: partes_perro("perro_negro", "perro_marron")),
    ("perro_blanco", "perro", lambda: partes_perro("perro_blanco", "perro_marron")),
    ("perro_bolt", "perro", lambda: partes_perro("perro_blanco", "perro_blanco", bolt=True)),
    ("gato_naranja", "gato", lambda: partes_gato("gato_naranja", "blanco")),
    ("gato_negro", "gato", lambda: partes_gato("perro_negro", "perro_negro")),
    ("gato_gris", "gato", lambda: partes_gato("persiana", "blanco")),
]


def limpiar_escena():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    for coleccion in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions, bpy.data.cameras):
        for d in list(coleccion):
            coleccion.remove(d)
    bpy.context.view_layer.update()


def exportar(nombre, especie, partes):
    limpiar_escena()
    arm = armadura(nombre, HUESOS_PERRO if especie == "perro" else HUESOS_GATO)
    me = malla(nombre, partes(), arm)
    (animaciones_perro if especie == "perro" else animaciones_gato)(arm)
    _activar([arm, me])
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, nombre + ".glb"), export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=False, export_materials="NONE", export_cameras=False,
                              export_lights=False, export_skins=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                              export_def_bones=False, export_reset_pose_bones=True)
    tris = sum(len(p.vertices) - 2 for p in me.data.polygons)
    print("ANIMAL", nombre, "tris", tris, "anims", [t.name for t in arm.animation_data.nla_tracks])
    return arm, me


# ---------------------------------------------------------------- vista previa (hoja de cuadros)


def previa(nombre, arm, me, cuadros_por_anim=5):
    """Hoja con cada animación en filas y algunos cuadros en columnas, vista de costado."""
    SCENE.render.engine = "BLENDER_WORKBENCH"
    SCENE.display.shading.light = "STUDIO"
    SCENE.display.shading.color_type = "TEXTURE"
    SCENE.render.resolution_x = 300
    SCENE.render.resolution_y = 240
    SCENE.render.film_transparent = False
    mat = bpy.data.materials.new("previa")
    mat.use_nodes = True
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = paleta.imagen(bpy, "paleta_previa", DIR_PREVIAS)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    me.data.materials.clear()
    me.data.materials.append(mat)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    SCENE.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.9
    cam.location = (2.6, -0.9, 0.75)
    cam.rotation_euler = (math.radians(86), 0, math.radians(70))
    SCENE.camera = cam
    filas = []
    for pista in arm.animation_data.nla_tracks:
        for p in arm.animation_data.nla_tracks:
            p.mute = p != pista
        tira = pista.strips[0]
        n0, n1 = int(tira.frame_start), int(tira.frame_end)
        fila = []
        for k in range(cuadros_por_anim):
            SCENE.frame_set(n0 + round((n1 - n0) * k / cuadros_por_anim))
            ruta = os.path.join(DIR_PREVIAS, "_cuadro.png")
            SCENE.render.filepath = ruta
            bpy.ops.render.render(write_still=True)
            img = bpy.data.images.load(ruta)
            px = np.array(img.pixels[:], dtype=np.float32).reshape(240, 300, 4)
            bpy.data.images.remove(img)
            fila.append(px)
        filas.append(np.concatenate(fila, axis=1))
    hoja = np.concatenate(list(reversed(filas)), axis=0)   # las imágenes de Blender van de abajo hacia arriba
    h, w = hoja.shape[:2]
    img = bpy.data.images.new(nombre + "_previa", w, h)
    img.pixels.foreach_set(hoja.ravel())
    img.filepath_raw = os.path.join(DIR_PREVIAS, nombre + ".png")
    img.file_format = "PNG"
    img.save()
    os.remove(os.path.join(DIR_PREVIAS, "_cuadro.png"))
    print("PREVIA", nombre, [p.name for p in arm.animation_data.nla_tracks])


for nombre, especie, partes in ANIMALES:
    arm, me = exportar(nombre, especie, partes)
    if PREVIA and nombre in ("perro_marron", "gato_naranja"):
        previa(nombre, arm, me)
