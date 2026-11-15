# Generador de las piezas del parque (estilo KayKit: paleta única con degradés y bordes biselados).
#
# Uso (sin abrir Blender):
#   F:/blender.exe -b --factory-startup -P tools/blender/generar_parque.py -- [--sin-render] [--sin-export]
#
# Salida:
#   modelos/parque/piezas/*.glb   props sueltos (árboles, bancos, faroles, fuente...)
#   modelos/parque/losetas/*.glb  losetas de 6x6 m (pasto, caminos, muros, portal) y losetas armadas
#   modelos/parque/fuente/        parque.blend + paleta (ignorado por Godot)
#   modelos/parque/previas/       renders de vista previa (ignorado por Godot)
#
# Convenciones: metros reales, Z arriba en Blender (Y arriba en Godot). Cada pieza tiene el
# origen en el centro de su base. Las losetas miden 6x6 m y su superficie está a 0,2 m.
# Los bancos miran hacia -Y en Blender (+Z en Godot).

import bpy, bmesh, math, random, os, sys
import numpy as np
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "modelos", "parque")
DIR_PIEZAS = os.path.join(OUT, "piezas")
DIR_LOSETAS = os.path.join(OUT, "losetas")
DIR_FUENTE = os.path.join(OUT, "fuente")
DIR_PREVIAS = os.path.join(OUT, "previas")

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
HACER_RENDER = "--sin-render" not in args
HACER_EXPORT = "--sin-export" not in args

for d in (DIR_PIEZAS, DIR_LOSETAS, DIR_FUENTE, DIR_PREVIAS):
    os.makedirs(d, exist_ok=True)
for d in (DIR_FUENTE, DIR_PREVIAS):
    open(os.path.join(d, ".gdignore"), "w").close()

bpy.ops.wm.read_factory_settings(use_empty=True)
SCENE = bpy.context.scene

TILE = 6.0
H = TILE / 2
T = 0.2            # altura de la superficie de la loseta
SW = T + 0.07      # altura de la vereda bajo los muros

# ---------------------------------------------------------------- paleta
# La misma paleta (y la misma disposición de celdas) que el kit de la ciudad
# (tools/blender/generar_ciudad.py): así en Godot las piezas de los dos kits comparten un solo
# material y se fusionan juntas. Si se cambia un color, cambiarlo en los dos scripts.
PAL = [  # nombre, arriba, abajo (sRGB)
    ("pasto", "3fa865", "277a4a"), ("hoja", "5cd068", "238a45"), ("hoja_osc", "45b85c", "1d7340"),
    ("tronco", "c4683f", "8a3f28"), ("piedra", "d5dde3", "9aa5ae"), ("piedra_osc", "aeb8c0", "7d8790"),
    ("agua", "8fdcff", "3a9be0"), ("madera", "e9844a", "b0522e"),
    ("metal", "4b5359", "23282c"), ("luz", "fff4b8", "ffcf5c"), ("tierra", "9a6a44", "6a452b"),
    ("flor_rosa", "ff9ec4", "e0628f"), ("flor_amarilla", "ffe46b", "f2b53a"), ("jacaranda", "c3a6ff", "7f5ad1"),
    ("arena", "f7cf98", "dda066"), ("blanco", "ffffff", "dde2e8"),
    ("fachada_crema", "f6e7c8", "d8c096"), ("fachada_terracota", "eda07a", "bd6a4b"),
    ("fachada_rosa", "f5bdb4", "cf8b86"), ("fachada_celeste", "bfe2f3", "84b2d3"),
    ("fachada_verde", "c4e8cd", "8bbe9d"), ("fachada_amarilla", "f9de8e", "deb258"),
    ("fachada_gris", "dcdcd6", "a6a7a2"), ("fachada_lila", "ddcbee", "a996c7"),
    ("ladrillo", "d07a55", "974a30"), ("fachada_beige", "ecdcc0", "c3aa86"), ("medianera", "c8bba8", "928574"),
    ("vidrio", "a6d8f5", "3f6f9e"), ("vidrio_osc", "6a8ba6", "26384b"), ("marco", "fbf9f4", "cdc8be"),
    ("persiana", "dfe3e6", "a3a9ae"), ("hierro", "454b51", "1b1e21"),
    ("toldo_rojo", "ec5e4f", "b2392f"), ("toldo_verde", "54b47f", "2c7a53"), ("toldo_azul", "5590d8", "2e599c"),
    ("toldo_amarillo", "ffcd52", "de9628"), ("toldo_naranja", "ffa058", "d6672a"),
    ("asfalto", "5f6268", "3c3e43"), ("vereda", "dcd5c6", "b6ad9c"), ("cordon", "eae7e0", "b9b5ad"),
    ("pizarra", "75849a", "48526a"), ("cupula", "93c4b8", "5b8d84"), ("tejas", "dc784c", "a5472b"),
    ("chapa", "bac3c9", "7a838a"), ("oxido", "cc8148", "86482a"), ("tanque", "4a5056", "1f2327"),
    ("plastico_rojo", "ff6255", "cc3328"), ("plastico_azul", "56aaff", "2c6bd0"),
    ("plastico_amarillo", "ffdc55", "eea52c"), ("plastico_verde", "74e070", "37a648"),
    ("azotea", "c99079", "93604b"), ("goma_azul", "6596d8", "3f629c"),
    ("perro_blanco", "fcfcf8", "d6d3cb"), ("perro_marron", "d0925a", "8c5832"), ("perro_negro", "54504d", "262220"),
    ("gato_naranja", "f5a656", "bf6a28"), ("grafiti_rosa", "ff66b8", "cf2f7d"), ("grafiti_cian", "55e6e6", "21a6b6"),
    ("grafiti_lima", "cdf460", "8cbe2c"), ("contenedor", "56a462", "2d683a"), ("buzon", "e8503f", "a5291f"),
    ("sombra", "50545d", "2a2c32"), ("naranja", "ff9145", "dd5a1d"), ("kiosco", "3a7d58", "1c4a33"),
]
assert len(PAL) == 64, len(PAL)
PIDX = {p[0]: i for i, p in enumerate(PAL)}
CELLS = 8
TEX = 512
CS = TEX // CELLS
MARGEN = 6.0 / CS   # los degradés no llegan al borde de la celda (no se mezclan colores vecinos)


def hex_rgb(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], dtype=np.float32)


def imagen_paleta(nombre, solo=None):
    arr = np.zeros((TEX, TEX, 4), dtype=np.float32)
    arr[..., 3] = 1
    for i, (n, top, bot) in enumerate(PAL):
        if solo and n not in solo:
            continue
        cx, cy = i % CELLS, i // CELLS
        a, b = hex_rgb(bot), hex_rgb(top)
        for r in range(CS):
            t = min(max((r / (CS - 1) - MARGEN) / (1 - 2 * MARGEN), 0.0), 1.0)
            arr[cy * CS + r, cx * CS:(cx + 1) * CS, :3] = a + (b - a) * t
    img = bpy.data.images.new(nombre, TEX, TEX, alpha=False)
    img.pixels.foreach_set(arr.ravel())
    img.filepath_raw = os.path.join(DIR_FUENTE, nombre + ".png")
    img.file_format = "PNG"
    img.save()
    return img


PIDX["arco"] = PIDX["naranja"]   # el arco del portal usa el naranja de la paleta de la ciudad


IMG = imagen_paleta("parque_paleta")
IMG_EM = imagen_paleta("parque_emision", solo={"luz"})


def material():
    mat = bpy.data.materials.new("parque")
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        nt.nodes.clear()
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(bsdf.outputs[0], out.inputs[0])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = IMG
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    em = nt.nodes.new("ShaderNodeTexImage")
    em.image = IMG_EM
    nt.links.new(em.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 2.0
    bsdf.inputs["Roughness"].default_value = 0.85
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.25
    return mat


MAT = material()

# ---------------------------------------------------------------- colecciones
def coleccion(nombre, padre=None):
    c = bpy.data.collections.new(nombre)
    (padre or SCENE.collection).children.link(c)
    return c


COL_TRABAJO = coleccion("Trabajo")
COL_PIEZAS = coleccion("Piezas")
COL_LOSETAS = coleccion("Losetas")
ASSETS = {}

# ---------------------------------------------------------------- geometría
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


def bm_blob(c, r, sc=(1, 1, 1), sub=2, jitter=0.0, rng=None):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    for v in bm.verts:
        co = v.co.copy()
        if jitter and rng:
            co += co.normalized() * (rng.uniform(-jitter, jitter) * r)
        v.co = Vector((co.x * sc[0] + c[0], co.y * sc[1] + c[1], co.z * sc[2] + c[2]))
    return bm


def limpiar(pts):
    out = []
    for p in pts:
        if not out or (Vector(p[:2]) - Vector(out[-1][:2])).length > 1e-5:
            out.append(p)
    if len(out) > 2 and (Vector(out[0][:2]) - Vector(out[-1][:2])).length < 1e-5:
        out.pop()
    return out


def bm_prisma(pts, z0, z1):
    pts = limpiar(pts)
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    if area < 0:
        pts = pts[::-1]
    bm = bmesh.new()
    bot = [bm.verts.new((x, y, z0)) for x, y in pts]
    top = [bm.verts.new((x, y, z1)) for x, y in pts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    return bm


def bm_anillo(ro, ri, z0, z1, seg=32, cx=0, cy=0):
    bm = bmesh.new()

    def circ(r, z):
        return [bm.verts.new((cx + r * math.cos(2 * math.pi * i / seg), cy + r * math.sin(2 * math.pi * i / seg), z)) for i in range(seg)]

    ob, ot, ib, it = circ(ro, z0), circ(ro, z1), circ(ri, z0), circ(ri, z1)
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((ob[i], ob[j], ot[j], ot[i]))
        bm.faces.new((it[i], it[j], ib[j], ib[i]))
        bm.faces.new((ot[i], ot[j], it[j], it[i]))
        bm.faces.new((ib[i], ib[j], ob[j], ob[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def circulo(r, seg=32, cx=0, cy=0):
    return [(cx + r * math.cos(2 * math.pi * i / seg), cy + r * math.sin(2 * math.pi * i / seg)) for i in range(seg)]


def arco(cx, cy, r, a0, a1, n=12):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def bm_barrido(path, prof, ref=(0, 0, 1), tapas=True):
    path = [Vector(p) for p in path]
    path = [p for i, p in enumerate(path) if i == 0 or (p - path[i - 1]).length > 1e-5]
    n = len(path)
    bm = bmesh.new()
    anillos = []
    for i, p in enumerate(path):
        if i == 0:
            t = path[1] - path[0]
        elif i == n - 1:
            t = path[-1] - path[-2]
        else:
            t = (path[i + 1] - path[i]).normalized() + (path[i] - path[i - 1]).normalized()
        t.normalize()
        lado = t.cross(Vector(ref)).normalized()
        arriba = lado.cross(t)
        anillos.append([bm.verts.new(p + lado * o + arriba * h) for o, h in prof])
    m = len(prof)
    for i in range(n - 1):
        a, b = anillos[i], anillos[i + 1]
        for k in range(m):
            l = (k + 1) % m
            bm.faces.new((a[k], a[l], b[l], b[k]))
    if tapas:
        bm.faces.new(anillos[0])
        bm.faces.new(anillos[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def banda(path2d, o_der, o_izq):
    """Polígono que rodea un camino 2D: o_der hacia la derecha del avance, o_izq hacia la izquierda."""
    path = [Vector((p[0], p[1], 0)) for p in limpiar(path2d)]
    n = len(path)
    der, izq = [], []
    for i, p in enumerate(path):
        if i == 0:
            t = path[1] - path[0]
        elif i == n - 1:
            t = path[-1] - path[-2]
        else:
            t = (path[i + 1] - path[i]).normalized() + (path[i] - path[i - 1]).normalized()
        t.normalize()
        lado = t.cross(Vector((0, 0, 1))).normalized()
        der.append((p + lado * o_der).to_2d())
        izq.append((p - lado * o_izq).to_2d())
    return [tuple(v) for v in der] + [tuple(v) for v in reversed(izq)]


# ---------------------------------------------------------------- objetos
def _merge(bms):
    if not isinstance(bms, (list, tuple)):
        return bms
    out = bmesh.new()
    for b in bms:
        tmp = bpy.data.meshes.new("_tmp")
        b.to_mesh(tmp)
        b.free()
        out.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    return out


def _activar(objs):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def pintar(o, color, zmin=None, zmax=None):
    me = o.data
    i = PIDX[color]
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    zs = [v.co.z for v in me.vertices]
    lo = min(zs) if zmin is None else zmin
    hi = max(zs) if zmax is None else zmax
    span = max(hi - lo, 1e-4)
    cx, cy = i % CELLS, i // CELLS
    u = (cx + 0.5) / CELLS
    for li, l in enumerate(me.loops):
        t = (me.vertices[l.vertex_index].co.z - lo) / span
        t = min(max(t, 0.0), 1.0)
        uv[li].uv = (u, (cy + MARGEN + t * (1 - 2 * MARGEN)) / CELLS)
    me.materials.clear()
    me.materials.append(MAT)


ANGULO_BISEL = math.radians(40)


def _en_borde(e, tol=1e-4):
    """¿La arista está apoyada en el borde de la loseta (plano x=±H o y=±H)?"""
    a, b = e.verts[0].co, e.verts[1].co
    for eje in (0, 1):
        for s in (-H, H):
            if abs(a[eje] - s) < tol and abs(b[eje] - s) < tol:
                return True
    return False


def parte(bms, color, bisel=0.0, plano=False, zmin=None, zmax=None, nombre="parte"):
    """Crea una parte con un solo color. bisel>0 redondea las aristas (como KayKit).

    Las aristas que caen en el borde de la loseta NUNCA se biselan: si se biselaran, al
    poner dos losetas juntas quedaría una ranura que se ve como una línea oscura."""
    bm = _merge(bms)
    bm.normal_update()
    if bisel > 0:
        peso = bm.edges.layers.float.new("bevel_weight_edge")
        for e in bm.edges:
            filosa = len(e.link_faces) == 2 and e.calc_face_angle(0) > ANGULO_BISEL
            if filosa and _en_borde(e):
                e.smooth = False  # arista viva y sombreado cortado, sin bisel
            elif filosa:
                e[peso] = 1.0
    me = bpy.data.meshes.new(nombre)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nombre, me)
    COL_TRABAJO.objects.link(o)
    for p in me.polygons:
        p.use_smooth = not plano
    if bisel > 0:
        mod = o.modifiers.new("bisel", "BEVEL")
        mod.width = bisel
        mod.segments = 1 if plano else 2
        mod.limit_method = "WEIGHT"
        if not plano:
            mod.harden_normals = True
        _activar([o])
        bpy.ops.object.modifier_apply(modifier=mod.name)
    pintar(o, color, zmin, zmax)
    return o


def ubicar(asset, loc=(0, 0, 0), rot=0.0, s=1.0):
    o = asset.copy()
    o.data = asset.data.copy()
    COL_TRABAJO.objects.link(o)
    o.matrix_world = Matrix.Translation(Vector(loc)) @ Matrix.Rotation(math.radians(rot), 4, "Z") @ Matrix.Scale(s, 4)
    return o


def unir(objs, nombre, col):
    objs = [o for o in objs if o]
    _activar(objs)
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = nombre
    o.data.name = nombre
    COL_TRABAJO.objects.unlink(o)
    col.objects.link(o)
    ASSETS[nombre] = o
    return o


# ================================================================= PROPS
def tronco(puntos, radios, seg=6):
    bms = []
    for i in range(len(puntos) - 1):
        bms.append(bm_cyl(puntos[i], puntos[i + 1], radios[i], radios[i + 1], seg))
    return bms


def copa(blobs, rng, color="hoja", sc_z=0.9):
    bms = [bm_blob(c, r, (1, 1, sc_z), 2, 0.07, rng) for c, r in blobs]
    return parte(bms, color, plano=True)


def arbol(nombre, seed, troncos, blobs, color="hoja", sc_z=0.9):
    rng = random.Random(seed)
    bms = []
    for pts, rs in troncos:
        bms += tronco(pts, rs)
    t = parte(bms, "tronco", plano=True)
    c = copa(blobs, rng, color, sc_z)
    return unir([t, c], nombre, COL_PIEZAS)


def hacer_arboles():
    arbol("arbol_A", 1,
          [([(0, 0, 0), (0, 0, 1.8)], [0.2, 0.13]), ([(0, 0, 1.2), (0.45, 0.1, 1.85)], [0.08, 0.05])],
          [((0, 0, 2.5), 1.0), ((0.78, 0.2, 2.25), 0.65), ((-0.72, 0.35, 2.3), 0.7), ((0.1, -0.72, 2.2), 0.65),
           ((-0.2, 0.5, 3.05), 0.6), ((0.35, -0.2, 3.1), 0.55)])
    arbol("arbol_B", 2,
          [([(0, 0, 0), (0, 0, 2.4)], [0.18, 0.12])],
          [((0, 0, 2.3), 0.85), ((0, 0, 3.1), 0.75), ((0.05, 0, 3.75), 0.5), ((0.5, 0.2, 2.6), 0.5),
           ((-0.45, -0.25, 2.8), 0.5), ((0.2, -0.45, 3.3), 0.42)], sc_z=1.0)
    arbol("arbol_C", 3,
          [([(0, 0, 0), (0.25, 0, 0.9), (0.75, 0.1, 1.8)], [0.19, 0.15, 0.11])],
          [((0.85, 0.1, 2.5), 0.85), ((0.3, 0.3, 2.35), 0.6), ((1.4, -0.1, 2.3), 0.55), ((0.9, 0.2, 3.1), 0.55),
           ((0.7, -0.45, 2.55), 0.5)])
    arbol("arbol_D", 4,
          [([(0, 0, 0), (0, 0, 1.1)], [0.12, 0.08])],
          [((0, 0, 1.45), 0.55), ((0.32, 0.1, 1.28), 0.36), ((-0.27, -0.15, 1.32), 0.36), ((0, 0.05, 1.85), 0.36)])
    arbol("arbol_E", 5,
          [([(0, 0, 0), (0, 0, 1.3)], [0.2, 0.15]), ([(0, 0, 1.25), (-0.65, 0.05, 2.15)], [0.11, 0.07]),
           ([(0, 0, 1.25), (0.55, 0.2, 2.45)], [0.11, 0.07])],
          [((-0.7, 0.05, 2.45), 0.7), ((-1.15, 0.2, 2.25), 0.45), ((-0.4, -0.35, 2.3), 0.45),
           ((0.6, 0.2, 2.8), 0.75), ((1.05, 0.0, 2.6), 0.45), ((0.35, 0.55, 2.65), 0.45), ((0.0, 0.1, 3.05), 0.5)])
    arbol("jacaranda", 6,
          [([(0, 0, 0), (0, 0, 1.6)], [0.22, 0.15]), ([(0, 0, 1.5), (-0.9, 0.3, 2.4)], [0.1, 0.06]),
           ([(0, 0, 1.5), (0.8, 0.5, 2.5)], [0.1, 0.06]), ([(0, 0, 1.5), (0.2, -0.9, 2.4)], [0.1, 0.06])],
          [((0, 0, 2.8), 1.1), ((-1.0, 0.35, 2.6), 0.85), ((0.95, 0.55, 2.65), 0.85), ((0.25, -1.0, 2.55), 0.85),
           ((-0.7, -0.7, 2.75), 0.7), ((0.6, -0.35, 3.1), 0.7), ((-0.3, 0.8, 3.1), 0.65)],
          color="jacaranda", sc_z=0.65)


def hacer_arbustos():
    def arbusto(nombre, blobs, seed, flores=0):
        rng = random.Random(seed)
        partes = [parte([bm_blob(c, r, (1, 1, 0.85), 2, 0.08, rng) for c, r in blobs], "hoja_osc", plano=True)]
        if flores:
            rosas, amarillas = [], []
            for k in range(flores):
                c, r = blobs[rng.randrange(len(blobs))]
                a = rng.uniform(0, 2 * math.pi)
                el = rng.uniform(math.radians(15), math.radians(80))
                d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el) * 0.85))
                p = Vector(c) + d * r * 0.97
                (rosas if k % 2 == 0 else amarillas).append(bm_blob(p, 0.075, (1, 1, 1), 1, 0, None))
            partes.append(parte(rosas, "flor_rosa", plano=True))
            partes.append(parte(amarillas, "flor_amarilla", plano=True))
        return unir(partes, nombre, COL_PIEZAS)

    arbusto("arbusto_A", [((0, 0, 0.28), 0.36)], 11)
    arbusto("arbusto_B", [((0, 0, 0.36), 0.45), ((0.42, 0.1, 0.27), 0.33), ((-0.33, 0.2, 0.25), 0.3)], 12)
    arbusto("arbusto_C", [((0, 0, 0.48), 0.6), ((0.58, 0.2, 0.33), 0.42), ((-0.52, 0.15, 0.32), 0.4),
                          ((0.1, -0.48, 0.3), 0.38), ((-0.1, 0.45, 0.36), 0.4)], 13)
    arbusto("arbusto_flores", [((0, 0, 0.36), 0.45), ((0.42, 0.1, 0.27), 0.33), ((-0.33, 0.2, 0.25), 0.3)], 14, flores=16)


def hacer_banco():
    madera, metal = [], []
    for y in (-0.17, -0.03, 0.11):
        madera.append(bm_box(1.6, 0.12, 0.05, 0, y, 0.42))
    for z in (0.58, 0.76):
        madera.append(bm_box(1.6, 0.05, 0.12, 0, 0.21, z))
    for x in (-0.66, 0.66):
        metal.append(bm_box(0.07, 0.07, 0.42, x, -0.17, 0))
        metal.append(bm_box(0.07, 0.07, 0.92, x, 0.2, 0))
        metal.append(bm_box(0.07, 0.42, 0.05, x, 0.0, 0.37))
        metal.append(bm_box(0.07, 0.42, 0.04, x, -0.0, 0.64))
        metal.append(bm_box(0.07, 0.07, 0.2, x, -0.17, 0.46))
    unir([parte(madera, "madera", bisel=0.015, zmin=0.3, zmax=0.9), parte(metal, "metal", plano=True)], "banco", COL_PIEZAS)


def farolito(x, y, z0):
    """Linterna sobre (x, y, z0). Devuelve (metal, vidrio)."""
    metal = [bm_cyl((x, y, z0), (x, y, z0 + 0.05), 0.12, 0.12, 6),
             bm_cyl((x, y, z0 + 0.35), (x, y, z0 + 0.53), 0.21, 0.04, 6),
             bm_blob((x, y, z0 + 0.57), 0.045, sub=1)]
    for k in range(6):
        a = math.radians(30 + 60 * k)
        metal.append(bm_cyl((x + 0.15 * math.cos(a), y + 0.15 * math.sin(a), z0 + 0.04),
                            (x + 0.19 * math.cos(a), y + 0.19 * math.sin(a), z0 + 0.36), 0.014, 0.014, 4))
    vidrio = [bm_cyl((x, y, z0 + 0.05), (x, y, z0 + 0.35), 0.14, 0.18, 6)]
    return metal, vidrio


def hacer_faroles():
    # Simple
    metal = [bm_cyl((0, 0, 0), (0, 0, 0.32), 0.15, 0.11, 8), bm_cyl((0, 0, 0.3), (0, 0, 2.75), 0.055, 0.05, 8),
             bm_cyl((0, 0, 0.9), (0, 0, 0.98), 0.08, 0.08, 8), bm_cyl((0, 0, 2.7), (0, 0, 2.78), 0.09, 0.09, 8)]
    m, v = farolito(0, 0, 2.78)
    unir([parte(metal + m, "metal", plano=True), parte(v, "luz", plano=True)], "farol", COL_PIEZAS)
    # Doble
    metal = [bm_cyl((0, 0, 0), (0, 0, 0.32), 0.16, 0.12, 8), bm_cyl((0, 0, 0.3), (0, 0, 2.75), 0.06, 0.055, 8),
             bm_cyl((0, 0, 0.9), (0, 0, 0.98), 0.085, 0.085, 8),
             bm_cyl((-0.5, 0, 2.6), (0.5, 0, 2.6), 0.04, 0.04, 6),
             bm_cyl((-0.3, 0, 2.6), (0, 0, 2.4), 0.025, 0.025, 4), bm_cyl((0.3, 0, 2.6), (0, 0, 2.4), 0.025, 0.025, 4),
             bm_cyl((0, 0, 2.72), (0, 0, 3.0), 0.04, 0.02, 6), bm_blob((0, 0, 3.03), 0.05, sub=1)]
    vidrios = []
    for x in (-0.5, 0.5):
        metal.append(bm_cyl((x, 0, 2.56), (x, 0, 2.64), 0.07, 0.07, 6))
        m, v = farolito(x, 0, 2.64)
        metal += m
        vidrios += v
    unir([parte(metal, "metal", plano=True), parte(vidrios, "luz", plano=True)], "farol_doble", COL_PIEZAS)


def hacer_fuente():
    piedra = [bm_anillo(1.5, 1.22, 0, 0.55), bm_anillo(1.6, 1.14, 0.55, 0.65),
              bm_cyl((0, 0, 0.1), (0, 0, 1.0), 0.22, 0.18, 8), bm_cyl((0, 0, 0.98), (0, 0, 1.2), 0.25, 0.62, 12),
              bm_cyl((0, 0, 1.2), (0, 0, 1.5), 0.08, 0.06, 8)]
    fondo = [bm_prisma(circulo(1.25), 0, 0.15)]
    agua = [bm_prisma(circulo(1.24), 0.15, 0.42), bm_prisma(circulo(0.55, 16), 1.12, 1.21),
            bm_blob((0, 0, 1.55), 0.11, (1, 1, 1.3), 1)]
    unir([parte(piedra, "piedra", bisel=0.03), parte(fondo, "piedra_osc", plano=True), parte(agua, "agua", plano=True, zmin=0, zmax=1.6)],
         "fuente", COL_PIEZAS)


def hacer_cantero():
    piedra = [bm_anillo(1.25, 1.05, 0, 0.45), bm_anillo(1.32, 1.0, 0.45, 0.53)]
    tierra = [bm_prisma(circulo(1.06), 0, 0.4)]
    unir([parte(piedra, "piedra", bisel=0.03), parte(tierra, "tierra", plano=True)], "cantero", COL_PIEZAS)


# ================================================================= LOSETAS
def base_pasto():
    return parte([bm_box(TILE, TILE, T)], "pasto", bisel=0.04)


def camino(pts):
    return parte([bm_prisma(pts, T - 0.06, T + 0.012)], "arena", plano=True, zmin=T - 0.06, zmax=T + 0.012)


def caminos(lista):
    return parte([bm_prisma(p, T - 0.06, T + 0.012) for p in lista], "arena", plano=True, zmin=T - 0.06, zmax=T + 0.012)


RECTO = [(-1, -H), (1, -H), (1, H), (-1, H)]
RECTO_X = [(-H, -1), (H, -1), (H, 1), (-H, 1)]
CURVA = arco(H, -H, 4, 180, 90, 16) + arco(H, -H, 2, 90, 180, 10)
T_UNION = [(-H, -1), (H, -1), (H, 1)] + arco(1.8, 1.8, 0.8, 270, 180, 6) + [(1, H), (-1, H)] + \
          arco(-1.8, 1.8, 0.8, 0, -90, 6) + [(-H, 1)]
CRUCE = [(-1, -H), (1, -H)] + arco(1.8, -1.8, 0.8, 180, 90, 6) + [(H, -1), (H, 1)] + arco(1.8, 1.8, 0.8, 270, 180, 6) + \
        [(1, H), (-1, H)] + arco(-1.8, 1.8, 0.8, 0, -90, 6) + [(-H, 1), (-H, -1)] + arco(-1.8, -1.8, 0.8, 90, 0, 6)
FIN = [(-1, -H), (1, -H), (1, 0)] + arco(0, 0, 1, 0, 180, 12) + [(-1, 0)]
PLAZA = arco(H, -H, 2, 180, 90, 10) + arco(H, H, 2, 270, 180, 10) + arco(-H, H, 2, 0, -90, 10) + arco(-H, -H, 2, 90, 0, 10)
CIRCULO = circulo(2.6, 40)

PERFIL_MURO = [(-0.22, 0), (0.22, 0), (0.22, 0.75), (0.3, 0.75), (0.3, 0.9), (-0.3, 0.9), (-0.3, 0.75), (-0.22, 0.75)]
MURO_RECTO = [(-H, 2.5), (H, 2.5)]
MURO_ESQUINA = [(-H, 2.5), (1.0, 2.5)] + arco(1.0, 1.0, 1.5, 90, 0, 12)[1:-1] + [(2.5, 1.0), (2.5, -H)]


def muro(path2d, vereda=True):
    path3 = [(x, y, SW) for x, y in path2d]
    partes = [parte([bm_barrido(path3, PERFIL_MURO)], "piedra", bisel=0.025, zmin=SW, zmax=SW + 0.9)]
    if vereda:
        partes.append(parte([bm_prisma(banda(path2d, 0.6, 0.5), T - 0.03, SW)], "piedra_osc", bisel=0.015))
    return partes


def pilar(x, y, alto=1.9):
    bms = [bm_box(0.6, 0.6, alto, x, y, SW), bm_box(0.76, 0.76, 0.14, x, y, SW + alto),
           bm_box(0.5, 0.5, 0.1, x, y, SW + alto + 0.14), bm_blob((x, y, SW + alto + 0.3), 0.13, sub=1)]
    return bms


def hacer_losetas_base():
    unir([base_pasto()], "pasto", COL_LOSETAS)
    unir([base_pasto(), camino(RECTO)], "camino_recto", COL_LOSETAS)
    unir([base_pasto(), camino(CURVA)], "camino_curva", COL_LOSETAS)
    unir([base_pasto(), camino(T_UNION)], "camino_t", COL_LOSETAS)
    unir([base_pasto(), camino(CRUCE)], "camino_cruce", COL_LOSETAS)
    unir([base_pasto(), camino(FIN)], "camino_fin", COL_LOSETAS)
    unir([base_pasto(), camino(PLAZA)], "plaza_cruce", COL_LOSETAS)
    unir([base_pasto(), caminos([CIRCULO, RECTO, RECTO_X])], "plaza_redonda", COL_LOSETAS)
    unir([base_pasto(), caminos([CIRCULO])], "plaza_circulo", COL_LOSETAS)
    unir([base_pasto()] + muro(MURO_RECTO), "muro_recto", COL_LOSETAS)
    unir([base_pasto()] + muro(MURO_ESQUINA), "muro_esquina", COL_LOSETAS)
    fin = muro([(-H, 2.5), (0.4, 2.5)])
    fin.append(parte(pilar(0.4, 2.5, 0.95), "piedra", bisel=0.025))
    fin.append(parte([bm_prisma(banda([(0.4, 2.5), (1.0, 2.5)], 0.6, 0.5), T - 0.03, SW)], "piedra_osc", bisel=0.015))
    unir([base_pasto()] + fin, "muro_fin", COL_LOSETAS)
    # Portal: camino que cruza un muro con dos pilares y un arco.
    partes = [base_pasto(), camino(RECTO)]
    partes += muro([(-H, 2.5), (-1.45, 2.5)], vereda=False) + muro([(1.45, 2.5), (H, 2.5)], vereda=False)
    partes.append(parte([bm_prisma(banda(MURO_RECTO, 0.6, 0.5), T - 0.03, SW)], "piedra_osc", bisel=0.015))
    partes.append(parte(pilar(-1.45, 2.5) + pilar(1.45, 2.5), "piedra", bisel=0.025))
    zc = SW + 1.85
    pts = [(1.45 * math.cos(math.radians(a)), 2.5, zc + 0.75 * math.sin(math.radians(a))) for a in range(0, 181, 10)]
    perfil = [(-0.07, -0.07), (0.07, -0.07), (0.07, 0.07), (-0.07, 0.07)]
    partes.append(parte([bm_barrido(pts, perfil, ref=(0, 1, 0))], "arco", bisel=0.015))
    unir(partes, "portal", COL_LOSETAS)


def hacer_losetas_armadas():
    A = ASSETS
    p = T  # los props van apoyados en la superficie

    def loseta(base, cosas, nombre):
        objs = [ubicar(A[base])] + [ubicar(A[n], (x, y, p + dz), r, s) for n, x, y, r, s, dz in cosas]
        unir(objs, nombre, COL_LOSETAS)

    def c(n, x, y, r=0, s=1, dz=0):
        return (n, x, y, r, s, dz)

    loseta("pasto", [c("arbol_A", -1.5, -1.4), c("arbol_B", 1.5, -1.3, 40), c("arbol_C", -1.6, 1.3, 200),
                     c("arbol_A", 1.6, 1.6, 120, 0.85), c("arbol_D", 0.1, 0.1, 60),
                     c("arbusto_B", 0.3, -2.4, 10), c("arbusto_C", -2.4, 0.0, 70), c("arbusto_A", 2.5, 0.2)], "bosque")
    benches = []
    for a in (45, 135, 225, 315):
        benches.append(c("banco", 2.2 * math.cos(math.radians(a)), 2.2 * math.sin(math.radians(a)), a - 90))
    loseta("plaza_redonda", [c("fuente", 0, 0)] + benches +
           [c("arbusto_B", 2.45, 2.45, 30), c("arbusto_B", -2.45, 2.45, 120), c("arbusto_B", -2.45, -2.45, 210),
            c("arbusto_B", 2.45, -2.45, 300)], "plaza_fuente")
    loseta("plaza_circulo", [c("cantero", 0, 0), c("arbol_A", 0, 0, 30, 0.8, 0.4), c("arbusto_A", 0.6, -0.55, 0, 0.8, 0.4),
                             c("arbusto_A", -0.6, 0.5, 0, 0.75, 0.4),
                             c("banco", 0, -2.0, 0), c("banco", 0, 2.0, 180),
                             c("arbusto_C", 2.4, 2.4, 20), c("arbusto_flores", -2.4, 2.4, 80), c("arbusto_C", -2.4, -2.4, 150),
                             c("arbusto_flores", 2.4, -2.4, 260)], "plaza_cantero")
    loseta("camino_recto", [c("farol", 1.45, 1.6), c("farol", -1.45, -1.6), c("banco", -1.6, 0.4, 90),
                            c("banco", 1.6, -0.4, -90), c("arbusto_C", -2.3, 2.3, 40), c("arbusto_B", 2.3, -2.3, 200),
                            c("arbusto_A", -2.4, -2.5), c("arbusto_flores", 2.4, 2.5)], "camino_faroles")
    loseta("camino_curva", [c("arbol_A", -1.7, 1.6, 20), c("arbol_D", 1.4, 2.2, 90), c("arbol_B", -2.0, -1.5, 160, 0.85),
                            c("banco", -0.25, 0.25, 45), c("arbusto_B", 2.4, -2.4, 0), c("arbusto_flores", 0.9, 0.9, 30)],
           "camino_curva_arboles")
    loseta("plaza_cruce", [c("arbusto_C", 2.35, 2.35, 10), c("arbusto_C", -2.35, 2.35, 100), c("arbusto_C", -2.35, -2.35, 190),
                           c("arbusto_C", 2.35, -2.35, 280)], "plaza_cruce_arbustos")
    loseta("muro_recto", [c("arbol_A", -1.7, 0.6, 30), c("arbol_E", 1.6, 0.4, 0), c("arbusto_B", 0.0, 1.25, 0),
                          c("arbusto_A", -0.2, -1.4)], "muro_arboles")
    loseta("muro_esquina", [c("arbol_B", -0.6, -0.6, 0), c("arbusto_C", 0.9, 0.7, 45), c("arbusto_A", -2.0, 1.2),
                            c("arbusto_A", 1.3, -2.0)], "muro_esquina_arbol")
    loseta("portal", [c("farol_doble", -2.1, 1.4), c("farol_doble", 2.1, 1.4), c("arbusto_B", -2.3, -1.0, 90),
                      c("arbusto_B", 2.3, -1.2, 270)], "portal_faroles")
    loseta("pasto", [c("jacaranda", 0.4, 0.6, 0), c("banco", 0.3, -1.5, 0), c("arbusto_flores", -2.0, -1.8, 40),
                     c("arbusto_B", 2.3, -1.9, 0), c("arbusto_A", -2.2, 2.0)], "jacaranda_banco")


# ================================================================= construir
hacer_arboles()
hacer_arbustos()
hacer_banco()
hacer_faroles()
hacer_fuente()
hacer_cantero()
hacer_losetas_base()
hacer_losetas_armadas()

# Limpieza de lo que quedó suelto
for o in list(COL_TRABAJO.objects):
    bpy.data.objects.remove(o)
for me in list(bpy.data.meshes):
    if me.users == 0:
        bpy.data.meshes.remove(me)

PROPS = [o.name for o in COL_PIEZAS.objects]
LOSETAS = [o.name for o in COL_LOSETAS.objects]

# ================================================================= export
stats = {}
for n, o in ASSETS.items():
    o.data.update()
    stats[n] = sum(len(p.vertices) - 2 for p in o.data.polygons)

if HACER_EXPORT:
    for n, o in ASSETS.items():
        _activar([o])
        carpeta = DIR_PIEZAS if n in PROPS else DIR_LOSETAS
        bpy.ops.export_scene.gltf(filepath=os.path.join(carpeta, n + ".glb"), export_format="GLB",
                                  use_selection=True, export_apply=True, export_yup=True,
                                  export_materials="NONE", export_cameras=False, export_lights=False)

# ================================================================= vitrina / renders
def srgb2lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def preparar_render():
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            SCENE.render.engine = eng
            break
        except TypeError:
            pass
    SCENE.render.resolution_x = 1600
    SCENE.render.resolution_y = 900
    SCENE.render.film_transparent = False
    try:
        SCENE.eevee.taa_render_samples = 64
    except Exception:
        pass
    for attr in ("use_raytracing", "use_gtao"):
        if hasattr(SCENE.eevee, attr):
            setattr(SCENE.eevee, attr, True)
    SCENE.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("mundo")
    SCENE.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.32, 0.36, 0.42, 1)
    bg.inputs["Strength"].default_value = 0.9
    sol = bpy.data.lights.new("sol", "SUN")
    sol.energy = 3.6
    sol.angle = math.radians(6)
    sol.color = (1.0, 0.96, 0.9)
    so = bpy.data.objects.new("sol", sol)
    so.rotation_euler = (math.radians(42), 0, math.radians(-35))
    SCENE.collection.objects.link(so)
    # Piso a cuadros oscuro (como las vitrinas de KayKit)
    me = bpy.data.meshes.new("piso")
    bm = bm_box(600, 600, 0.01, 0, 0, -0.011)
    bm.to_mesh(me)
    bm.free()
    piso = bpy.data.objects.new("piso", me)
    SCENE.collection.objects.link(piso)
    mp = bpy.data.materials.new("piso")
    try:
        mp.use_nodes = True
    except Exception:
        pass
    nt = mp.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    chk = nt.nodes.new("ShaderNodeTexChecker")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(tc.outputs["Object"], chk.inputs["Vector"])
    chk.inputs["Scale"].default_value = 600 / 8
    a, b = srgb2lin(0.095), srgb2lin(0.145)
    chk.inputs["Color1"].default_value = (a, a, a, 1)
    chk.inputs["Color2"].default_value = (b, b, b, 1)
    nt.links.new(chk.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    me.materials.append(mp)
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.clip_end = 1000
    co = bpy.data.objects.new("cam", cam)
    SCENE.collection.objects.link(co)
    SCENE.camera = co
    return co


def instancia(nombre, col, loc, rot=0.0):
    o = bpy.data.objects.new(nombre + "_v", ASSETS[nombre].data)
    o.location = loc
    o.rotation_euler = (0, 0, math.radians(rot))
    col.objects.link(o)
    return o


def encuadrar(cam, objs, az, el, margen=1.06):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centro = (mn + mx) / 2
    az, el = math.radians(az), math.radians(el)
    d = Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el)))
    cam.location = centro + d * 200
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    R = cam.rotation_euler.to_matrix()
    loc = [R.transposed() @ (p - cam.location) for p in pts]
    x0, x1 = min(p.x for p in loc), max(p.x for p in loc)
    y0, y1 = min(p.y for p in loc), max(p.y for p in loc)
    asp = SCENE.render.resolution_x / SCENE.render.resolution_y
    cam.data.ortho_scale = max(x1 - x0, (y1 - y0) * asp) * margen
    cam.location = cam.location + R @ Vector(((x0 + x1) / 2, (y0 + y1) / 2, 0))


def render(path):
    SCENE.render.filepath = path
    bpy.ops.render.render(write_still=True)


if HACER_RENDER:
    cam = preparar_render()
    COL_PIEZAS.hide_render = True
    COL_LOSETAS.hide_render = True
    vitrinas = {}

    # 1) Catálogo de losetas
    col = coleccion("Vitrina_losetas")
    orden = ["pasto", "camino_recto", "camino_curva", "camino_t", "camino_cruce",
             "camino_fin", "plaza_cruce", "plaza_redonda", "plaza_circulo", "muro_recto",
             "muro_esquina", "muro_fin", "portal", "bosque", "plaza_fuente",
             "plaza_cantero", "camino_faroles", "camino_curva_arboles", "plaza_cruce_arbustos", "muro_arboles",
             "muro_esquina_arbol", "portal_faroles", "jacaranda_banco"]
    objs = []
    for i, n in enumerate(orden):
        fila, colm = divmod(i, 6)
        objs.append(instancia(n, col, (colm * 7.6, -fila * 7.6, 0)))
    vitrinas["losetas"] = (col, objs, -62, 38)

    # 2) Catálogo de props
    col = coleccion("Vitrina_props")
    objs = []
    filas = [["arbol_A", "arbol_B", "arbol_C", "arbol_D", "arbol_E", "jacaranda"],
             ["arbusto_A", "arbusto_B", "arbusto_C", "arbusto_flores", "banco", "farol", "farol_doble", "fuente", "cantero"]]
    for fi, fila in enumerate(filas):
        x = 0.0
        for n in fila:
            o = ASSETS[n]
            w = o.dimensions.x
            x0 = min((Vector(c).x for c in o.bound_box))
            objs.append(instancia(n, col, (x - x0, -fi * 4.2, 0)))
            x += w + 0.7
    vitrinas["props"] = (col, objs, -62, 28)

    # 3) Parque armado 5x5
    col = coleccion("Vitrina_parque")
    objs = []
    plano = {}
    for i in range(5):
        for j in range(5):
            plano[(i, j)] = ("pasto", 0)
    for (i, j), r in {(4, 4): 0, (0, 4): 90, (0, 0): 180, (4, 0): -90}.items():
        plano[(i, j)] = ("muro_esquina_arbol", r)
    for i in (1, 3):
        plano[(i, 4)] = ("muro_arboles", 0)
        plano[(i, 0)] = ("muro_arboles", 180)
    for j in (1, 3):
        plano[(4, j)] = ("muro_arboles", -90)
        plano[(0, j)] = ("muro_arboles", 90)
    plano[(2, 4)] = ("portal_faroles", 0)
    plano[(2, 0)] = ("portal_faroles", 180)
    plano[(4, 2)] = ("portal_faroles", -90)
    plano[(0, 2)] = ("portal_faroles", 90)
    plano[(2, 3)] = ("camino_faroles", 0)
    plano[(2, 1)] = ("camino_faroles", 180)
    plano[(1, 2)] = ("camino_faroles", 90)
    plano[(3, 2)] = ("camino_faroles", -90)
    plano[(2, 2)] = ("plaza_fuente", 0)
    plano[(1, 1)] = ("bosque", 0)
    plano[(3, 3)] = ("bosque", 90)
    plano[(3, 1)] = ("plaza_cantero", 0)
    plano[(1, 3)] = ("jacaranda_banco", 0)
    for (i, j), (n, r) in plano.items():
        objs.append(instancia(n, col, ((i - 2) * TILE, (j - 2) * TILE, 0), r))
    vitrinas["parque"] = (col, objs, -58, 40)
    vitrinas["parque_cerca"] = (col, [o for o in objs if (abs(o.location.x) < 7 and abs(o.location.y) < 7)], -58, 30)
    # Control de uniones: 2x2 losetas de cerca (muro con portal, vereda y camino cruzando bordes).
    vitrinas["uniones"] = (col, [o for o in objs if -7 < o.location.x < 1 and o.location.y > 5], -58, 35)

    for nombre, (col, objs, az, el) in vitrinas.items():
        for c2, *_ in vitrinas.values():
            c2.hide_render = c2 is not col
        encuadrar(cam, objs, az, el)
        render(os.path.join(DIR_PREVIAS, nombre + ".png"))
    for c2, *_ in vitrinas.values():
        c2.hide_render = True
    COL_PIEZAS.hide_render = False
    COL_LOSETAS.hide_render = False

bpy.data.collections.remove(COL_TRABAJO)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_FUENTE, "parque.blend"))
print("RESUMEN_TRIS", sorted(stats.items(), key=lambda kv: kv[0]))
