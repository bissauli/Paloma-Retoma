# Kit de muebles para los interiores de los pasajes (world/pasaje.gd). Mapa V3.
#
#   blender -b --python tools/blender/generar_muebles.py [-- --sin-render]
#
# Estilo como KayKit Furniture Bits (low poly gordito, aristas biseladas, maderas cálidas y telas de
# colores) y, para los locales, como City Pack Interiors (mostradores, vitrinas, góndolas). Todo
# modelado acá, a mano: no se usa ningún archivo de esos packs.
#
# Usa la MISMA paleta que los kits de la ciudad y del parque (paleta.py): en Godot comparten un solo
# material (Kit.material) y se fusionan con el resto del mapa.
# Ejes de Blender: X ancho, Y profundidad (el frente mira a -Y), Z arriba. Origen: centro del piso.
# Sale en modelos/muebles/<nombre>.glb; las medidas (para escalar y ubicar) las anota world/muebles.gd.

import bpy, bmesh, math, random, os, sys
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "modelos", "muebles")
DIR_FUENTE = os.path.join(OUT, "fuente")
DIR_PREVIAS = os.path.join(OUT, "previas")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
HACER_RENDER = "--sin-render" not in args
for d in (OUT, DIR_FUENTE, DIR_PREVIAS):
    os.makedirs(d, exist_ok=True)
for d in (DIR_FUENTE, DIR_PREVIAS):
    open(os.path.join(d, ".gdignore"), "w").close()

bpy.ops.wm.read_factory_settings(use_empty=True)
SCENE = bpy.context.scene
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paleta  # noqa: E402

PIDX = paleta.PIDX
IMG = paleta.imagen(bpy, "muebles_paleta", DIR_FUENTE)
IMG_EM = paleta.imagen(bpy, "muebles_emision", DIR_FUENTE, solo=set(paleta.EMISION))


def material():
    mat = bpy.data.materials.new("muebles")
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = IMG
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    em = nt.nodes.new("ShaderNodeTexImage")
    em.image = IMG_EM
    nt.links.new(em.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 2.0
    bsdf.inputs["Roughness"].default_value = 0.85
    return mat


MAT = material()
COL_TRABAJO = bpy.data.collections.new("Trabajo")
SCENE.collection.children.link(COL_TRABAJO)
COL_PIEZAS = bpy.data.collections.new("Muebles")
SCENE.collection.children.link(COL_PIEZAS)
ASSETS = {}
RNG = random.Random(7)

# ---------------------------------------------------------------- geometría


def caja(sx, sy, sz, x=0, y=0, z=0):
    """Caja con la base en z (no el centro)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx + x, v.co.y * sy + y, v.co.z * sz + z + sz / 2))
    return bm


def cil(p0, p1, r0, r1=None, seg=10):
    r1 = r0 if r1 is None else r1
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    L = d.length
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r0, radius2=r1, depth=L)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation(p0) @ rot @ Matrix.Translation((0, 0, L / 2)), verts=bm.verts)
    return bm


def bola(c, r, sc=(1, 1, 1), sub=1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    for v in bm.verts:
        v.co = Vector((v.co.x * sc[0] + c[0], v.co.y * sc[1] + c[1], v.co.z * sc[2] + c[2]))
    return bm


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


def pintar(o, color):
    me = o.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    zs = [v.co.z for v in me.vertices]
    lo, hi = min(zs), max(zs)
    span = max(hi - lo, 1e-4)
    for li, l in enumerate(me.loops):
        uv[li].uv = paleta.uv(color, (me.vertices[l.vertex_index].co.z - lo) / span)
    me.materials.clear()
    me.materials.append(MAT)


def parte(bms, color, bisel=0.025, plano=False):
    """Una parte de un solo color; bisel > 0 redondea las aristas filosas (el look KayKit)."""
    bm = _merge(bms)
    bm.normal_update()
    if bisel > 0:
        peso = bm.edges.layers.float.new("bevel_weight_edge")
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(40):
                e[peso] = 1.0
    me = bpy.data.meshes.new("parte")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("parte", me)
    COL_TRABAJO.objects.link(o)
    for p in me.polygons:
        p.use_smooth = not plano
    if bisel > 0:
        mod = o.modifiers.new("bisel", "BEVEL")
        mod.width = bisel
        mod.segments = 2
        mod.limit_method = "WEIGHT"
        mod.harden_normals = True
        _activar([o])
        bpy.ops.object.modifier_apply(modifier=mod.name)
    pintar(o, color)
    return o


def mueble(nombre, partes):
    objs = [p for p in partes if p]
    _activar(objs)
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = nombre
    o.data.name = nombre
    COL_TRABAJO.objects.unlink(o)
    COL_PIEZAS.objects.link(o)
    ASSETS[nombre] = o
    return o


# ---------------------------------------------------------------- piezas que se repiten

LOMOS = ["toldo_rojo", "goma_azul", "toldo_amarillo", "toldo_verde", "flor_violeta", "naranja", "letrero_crema"]


def libros(x0, x1, y, z, prof, alto_max=0.3, rng=RNG):
    """Una fila de lomos de libros de colores entre x0 y x1 (cada libro, su parte)."""
    out = []
    x = x0
    while x < x1 - 0.05:
        a = rng.uniform(0.045, 0.08)
        h = rng.uniform(alto_max * 0.7, alto_max)
        out.append(parte(caja(min(a, x1 - x), prof, h, x + a / 2, y, z), rng.choice(LOMOS), 0, plano=True))
        x += a + 0.006
    return out


def pan(c, largo=0.26, color="madera"):
    o = bola(c, 1.0, (largo / 2, 0.075, 0.06), sub=2)
    return parte(o, color, 0)


def planta(x, y, z, r=0.22, alt=0.3, color="hoja"):
    return [parte(bola((x, y, z + r * 0.8), r, (1, 1, 1.05), sub=1), color, 0, plano=True),
            parte(bola((x + r * 0.5, y - r * 0.2, z + r * 1.3), r * 0.65, sub=1), "hoja_osc", 0, plano=True)]


def maceta_chica(x, y, z, r=0.13, color="tejas"):
    return [parte(cil((x, y, z), (x, y, z + r * 1.2), r * 0.8, r), color, 0.01)] + planta(x, y, z + r * 1.1, r * 1.2)


# ================================================================= OBSTÁCULOS (los esquiva la paloma)
# Costado: 1.0 x 0.68 x 3.6 (ancho, profundidad, alto). Arriba (colgado): ~1.0 x 1.0 x 0.64.
# Abajo (mesa o mostrador): 1.4 x 0.9 x 1.2.

def biblioteca():
    w, d, h = 1.0, 0.68, 3.6
    p = [parte(caja(0.08, d, h, -w / 2 + 0.04), "madera_osc"), parte(caja(0.08, d, h, w / 2 - 0.04), "madera_osc"),
         parte(caja(w + 0.06, d + 0.06, 0.1, 0, 0, h - 0.1), "madera_osc"),
         parte(caja(w, 0.04, h - 0.1, 0, 0, 0), "madera")]   # Tabique del medio (dos caras)
    z = 0.12
    while z < h - 0.4:
        p.append(parte(caja(w - 0.1, d, 0.05, 0, 0, z), "madera"))
        for lado in (-1, 1):
            p += libros(-w / 2 + 0.1, w / 2 - 0.1, lado * d / 4, z + 0.05, d / 2 - 0.06)
        z += 0.62
    mueble("biblioteca", p)


def estante_panes():
    w, d, h = 1.0, 0.68, 3.4
    p = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(parte(caja(0.05, 0.05, h, sx * (w / 2 - 0.03), sy * (d / 2 - 0.03)), "hierro", 0.01))
    z = 0.3
    k = 0
    while z < h - 0.2:
        p.append(parte(caja(w, d, 0.04, 0, 0, z), "madera", 0.01))
        for i in range(3):
            for lado in (-1, 1):
                p.append(pan((-0.3 + i * 0.3, lado * 0.15, z + 0.1), 0.24 if (i + k) % 2 else 0.3,
                             "madera" if (i + k) % 3 else "toldo_naranja"))
        z += 0.65
        k += 1
    mueble("estante_panes", p)


def torre_macetas():
    w, d, h = 1.0, 0.68, 3.4
    p = [parte(caja(0.07, 0.07, h, 0, 0), "madera_osc", 0.015)]
    z = 0.5
    k = 0
    while z < h - 0.3:
        dx = 0.25 if k % 2 == 0 else -0.25
        p.append(parte(caja(0.55, 0.36, 0.05, dx * 0.6, 0, z - 0.05), "madera", 0.01))
        p += maceta_chica(dx, 0, z, 0.14, "tejas" if k % 2 else "goma_azul")
        if k % 2 == 0:
            p.append(parte(bola((dx + 0.12, -0.1, z + 0.45), 0.06, sub=1), "flor_rosa", 0))
        z += 0.72
        k += 1
    mueble("torre_macetas", p)


def archivero():
    w, d, h = 1.0, 0.68, 3.2
    p = [parte(caja(w, d, h, 0, 0, 0), "persiana", 0.03)]
    z = 0.2
    while z < h - 0.3:
        for lado in (-1, 1):
            p.append(parte(caja(w - 0.12, 0.02, 0.52, 0, lado * (d / 2 + 0.005), z), "chapa", 0.01))
            p.append(parte(caja(0.2, 0.04, 0.05, 0, lado * (d / 2 + 0.02), z + 0.38), "hierro", 0.01))
        z += 0.6
    p += maceta_chica(0.25, 0, h, 0.12, "blanco")
    mueble("archivero", p)


def planta_alta():
    p = [parte(cil((0, 0, 0), (0, 0, 0.6), 0.3, 0.36, 12), "blanco", 0.02),
         parte(cil((0, 0, 0.55), (0, 0, 2.0), 0.035, 0.03, 6), "tronco", 0)]
    for i, (z, r) in enumerate([(2.9, 0.42), (2.4, 0.38), (1.85, 0.34)]):
        a = i * 2.1
        p.append(parte(bola((math.cos(a) * 0.12, math.sin(a) * 0.1, z), r, (1, 1, 0.85), sub=1), "hoja" if i % 2 else "hoja_osc", 0, plano=True))
    mueble("planta_alta", p)


def heladera_vitrina():
    w, d, h = 1.0, 0.68, 3.4
    p = [parte(caja(w, d, h, 0, 0, 0), "blanco", 0.04),
         parte(caja(w + 0.02, d + 0.02, 0.35, 0, 0, h - 0.45), "toldo_rojo", 0.02)]
    for lado in (-1, 1):
        p.append(parte(caja(w - 0.14, 0.02, h - 1.0, 0, lado * (d / 2 + 0.006), 0.4), "vidrio", 0.01))
        z = 0.55
        k = 0
        while z < h - 0.8:
            for i in range(4):
                col = ["plastico_rojo", "plastico_azul", "plastico_amarillo", "plastico_verde"][(i + k) % 4]
                p.append(parte(caja(0.14, 0.04, 0.22, -0.33 + i * 0.22, lado * (d / 2 + 0.02), z), col, 0, plano=True))
            z += 0.5
            k += 1
    mueble("heladera_vitrina", p)


def lampara_verde():
    p = [parte(cil((0, 0, 0.16), (0, 0, 0.6), 0.45, 0.12, 14), "toldo_verde", 0.02),
         parte(bola((0, 0, 0.15), 0.12, sub=2), "luz", 0),
         parte(cil((0, 0, 0.58), (0, 0, 0.64), 0.06, 0.04, 8), "metal", 0)]
    mueble("lampara_verde", p)


def canasto_panes():
    p = [parte(cil((0, 0, 0.0), (0, 0, 0.3), 0.38, 0.46, 14), "madera", 0.02),
         parte(cil((0, 0, 0.28), (0, 0, 0.34), 0.47, 0.47, 14), "madera_osc", 0.01)]
    for i in range(5):
        a = i * 1.26
        p.append(pan((math.cos(a) * 0.2, math.sin(a) * 0.2, 0.36), 0.26, "madera" if i % 2 else "toldo_naranja"))
    for i in range(3):
        a = i * 2.094
        p.append(parte(cil((math.cos(a) * 0.44, math.sin(a) * 0.44, 0.32), (0, 0, 0.64), 0.008, 0.008, 4), "letrero_crema", 0))
    mueble("canasto_panes", p)


def sabana():
    """Sábana colgada de una soga, con una onda y dos broches (ancho en X, finita en Y)."""
    bm = bmesh.new()
    n, w, h = 8, 1.0, 0.6
    filas = []
    for j in range(3):
        fila = []
        for i in range(n + 1):
            x = -w / 2 + w * i / n
            y = math.sin(i * 1.4) * 0.03 * (j + 1) / 3
            fila.append(bm.verts.new((x, y, h - h * j / 2)))
        filas.append(fila)
    for j in range(2):
        for i in range(n):
            bm.faces.new((filas[j][i], filas[j][i + 1], filas[j + 1][i + 1], filas[j + 1][i]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.025)
    color = RNG.choice(["flor_blanca", "fachada_celeste", "flor_rosa"])
    p = [parte(bm, color, 0, plano=True),
         parte(cil((-0.6, 0, 0.62), (0.6, 0, 0.62), 0.008, 0.008, 4), "letrero_crema", 0)]
    for x in (-0.32, 0.32):
        p.append(parte(caja(0.03, 0.05, 0.08, x, 0, 0.56), "toldo_rojo", 0.005))
    mueble("sabana", p)


def ventilador():
    p = [parte(cil((0, 0, 0.12), (0, 0, 0.3), 0.12, 0.1, 12), "blanco", 0.015),
         parte(cil((0, 0, 0.3), (0, 0, 0.4), 0.025, 0.025, 6), "metal", 0),
         parte(bola((0, 0, 0.1), 0.08, sub=2), "luz", 0)]
    for i in range(4):
        a = i * math.pi / 2 + 0.3
        b = caja(0.42, 0.13, 0.025, 0, 0, 0)
        bmesh.ops.transform(b, matrix=Matrix.Translation((math.cos(a) * 0.29, math.sin(a) * 0.29, 0.18)) @ Matrix.Rotation(a, 4, "Z"), verts=b.verts)
        p.append(parte(b, "madera", 0.01))
    mueble("ventilador", p)


def salames():
    p = [parte(caja(1.0, 0.06, 0.06, 0, 0, 0.58), "hierro", 0.01)]
    for i, x in enumerate((-0.36, -0.12, 0.36)):
        p.append(parte(cil((x, 0, 0.58), (x, 0, 0.1 + 0.05 * i), 0.008, 0.008, 4), "letrero_crema", 0))
        p.append(parte(cil((x, 0, 0.1 + 0.05 * i), (x, 0, -0.25 + 0.05 * i), 0.065, 0.06, 10), "remate_marron", 0.02))
    p.append(parte(cil((0.12, 0, 0.58), (0.12, 0, 0.38), 0.008, 0.008, 4), "letrero_crema", 0))
    p.append(parte(bola((0.12, 0, 0.18), 0.16, (1, 0.8, 1.4), sub=2), "fachada_salmon", 0))   # Jamón
    mueble("salames", p)


def mesa_lectura():
    w, d, h = 1.4, 0.9, 0.85
    p = [parte(caja(w, d, 0.07, 0, 0, h - 0.07), "madera", 0.02)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(parte(caja(0.08, 0.08, h - 0.07, sx * (w / 2 - 0.1), sy * (d / 2 - 0.1)), "madera_osc", 0.015))
    z = h
    for i, c in enumerate(["toldo_rojo", "goma_azul", "toldo_amarillo"]):
        p.append(parte(caja(0.36 - i * 0.03, 0.26, 0.07, -0.25, 0.05, z), c, 0.01))
        z += 0.07
    p.append(parte(cil((0.35, 0, h), (0.35, 0, h + 0.28), 0.015, 0.015, 6), "metal", 0))
    p.append(parte(cil((0.35, 0, h + 0.22), (0.35, 0, h + 0.34), 0.13, 0.05, 10), "toldo_verde", 0.01))
    mueble("mesa_lectura", p)


def mostrador_torta():
    w, d, h = 1.4, 0.9, 1.0
    p = [parte(caja(w, d, h - 0.06, 0, 0, 0), "letrero_crema", 0.03),
         parte(caja(w + 0.06, d + 0.06, 0.06, 0, 0, h - 0.06), "piedra", 0.015),
         parte(caja(w - 0.2, 0.02, 0.5, 0, -d / 2 - 0.005, 0.25), "fachada_rosa", 0.01),
         parte(cil((0, 0, h), (0, 0, h + 0.03), 0.3, 0.3, 14), "blanco", 0.005),
         parte(cil((0, 0, h + 0.03), (0, 0, h + 0.18), 0.24, 0.24, 14), "flor_rosa", 0.015),
         parte(cil((0, 0, h + 0.18), (0, 0, h + 0.2), 0.245, 0.245, 14), "blanco", 0.005),
         parte(bola((0, 0, h + 0.23), 0.035, sub=2), "toldo_rojo", 0)]
    mueble("mostrador_torta", p)


def mesa_mate():
    w, d, h = 1.0, 0.8, 0.8
    p = [parte(caja(w, d, 0.05, 0, 0, h - 0.05), "madera", 0.015),
         parte(caja(w + 0.12, d + 0.12, 0.012, 0, 0, h), "toldo_rojo", 0.004)]   # Mantel
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(parte(cil((sx * (w / 2 - 0.1), sy * (d / 2 - 0.1), 0), (sx * (w / 2 - 0.1), sy * (d / 2 - 0.1), h - 0.05), 0.035, 0.03, 8), "madera_osc", 0))
    p.append(parte(cil((0.2, 0, h), (0.2, 0, h + 0.32), 0.06, 0.06, 10), "toldo_verde", 0.01))
    p.append(parte(cil((0.2, 0, h + 0.32), (0.2, 0, h + 0.37), 0.04, 0.05, 10), "auto_negro", 0.005))
    p.append(parte(bola((-0.15, 0.05, h + 0.07), 0.07, (1, 1, 1.1), sub=2), "madera_osc", 0))
    p.append(parte(cil((-0.15, 0.05, h + 0.13), (-0.15, 0.05, h + 0.14), 0.05, 0.05, 10), "hoja_osc", 0))
    p.append(parte(cil((-0.14, 0.05, h + 0.1), (-0.1, 0.05, h + 0.24), 0.006, 0.006, 4), "llanta", 0))
    mueble("mesa_mate", p)


def escritorio_pc():
    w, d, h = 1.4, 0.9, 0.78
    p = [parte(caja(w, d, 0.06, 0, 0, h - 0.06), "madera", 0.02)]
    for sx in (-1, 1):
        p.append(parte(caja(0.06, d - 0.08, h - 0.06, sx * (w / 2 - 0.05)), "poste", 0.01))
    p.append(parte(caja(0.55, 0.06, 0.36, 0, 0.2, h + 0.12), "auto_negro", 0.02))       # Monitor
    p.append(parte(caja(0.47, 0.012, 0.28, 0, 0.165, h + 0.16), "agua", 0))           # Pantalla
    p.append(parte(caja(0.08, 0.08, 0.12, 0, 0.22, h), "auto_negro", 0.01))
    p.append(parte(caja(0.42, 0.14, 0.025, 0, -0.15, h), "interior", 0.008))          # Teclado
    p.append(parte(cil((0.48, -0.15, h), (0.48, -0.15, h + 0.1), 0.045, 0.045, 10), "fachada_celeste", 0.005))  # Taza
    p += maceta_chica(-0.5, 0.15, h, 0.08, "blanco")
    mueble("escritorio_pc", p)


def mostrador_quesos():
    w, d, h = 1.4, 0.9, 1.0
    p = [parte(caja(w, d, h - 0.3, 0, 0, 0), "blanco", 0.03),
         parte(caja(w - 0.1, 0.03, 0.26, 0, -d / 2 + 0.05, h - 0.3), "vidrio", 0.008),
         parte(caja(w, d, 0.04, 0, 0, h - 0.3), "piedra", 0.01)]
    for i, x in enumerate((-0.35, 0.05, 0.4)):
        p.append(parte(cil((x, 0.1, h - 0.26), (x, 0.1, h - 0.26 + 0.16), 0.17, 0.17, 12), "flor_amarilla", 0.02))
        if i == 1:
            p.append(parte(cil((x, 0.1, h - 0.1), (x, 0.1, h + 0.0), 0.14, 0.14, 12), "toldo_amarillo", 0.015))
    p.append(parte(caja(0.5, 0.3, 0.04, 0, -0.2, h - 0.26), "madera", 0.01))
    p.append(parte(bola((0, -0.2, h - 0.17), 0.07, (1.4, 1, 0.8), sub=1), "fachada_salmon", 0))
    mueble("mostrador_quesos", p)


# ================================================================= ADORNOS (contra las paredes)

def sillon(nombre, tela):
    w, d = 2.0, 0.9
    p = [parte(caja(w, d, 0.32, 0, 0, 0.1), tela, 0.06),
         parte(caja(w, 0.25, 0.55, 0, d / 2 - 0.12, 0.35), tela, 0.08)]
    for sx in (-1, 1):
        p.append(parte(caja(0.22, d, 0.45, sx * (w / 2 - 0.1), 0, 0.3), tela, 0.08))
        for sy in (-1, 1):
            p.append(parte(caja(0.07, 0.07, 0.1, sx * (w / 2 - 0.12), sy * (d / 2 - 0.1)), "madera_osc", 0.01))
    for sx in (-0.42, 0.42):
        p.append(parte(caja(0.75, 0.6, 0.16, sx, -0.08, 0.42), tela, 0.06))   # Almohadones
    p.append(parte(caja(0.35, 0.12, 0.3, 0.55, 0.22, 0.58), "toldo_amarillo" if tela != "toldo_amarillo" else "goma_azul", 0.05))
    mueble(nombre, p)


def silla():
    p = [parte(caja(0.46, 0.46, 0.06, 0, 0, 0.44), "madera", 0.015),
         parte(caja(0.46, 0.06, 0.5, 0, 0.2, 0.5), "madera", 0.015)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(parte(caja(0.05, 0.05, 0.44, sx * 0.19, sy * 0.19), "madera_osc", 0.01))
    p.append(parte(caja(0.42, 0.4, 0.05, 0, -0.02, 0.5), "goma_azul", 0.02))
    mueble("silla", p)


def mesa_ratona():
    p = [parte(caja(1.0, 0.6, 0.06, 0, 0, 0.36), "madera", 0.02)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(parte(caja(0.06, 0.06, 0.36, sx * 0.42, sy * 0.22), "madera_osc", 0.01))
    p.append(parte(cil((0.2, 0, 0.42), (0.2, 0, 0.52), 0.06, 0.05, 10), "fachada_celeste", 0.01))
    p += libros(-0.4, -0.1, 0, 0.42, 0.2, 0.06)
    mueble("mesa_ratona", p)


def alfombra():
    bm = caja(2.4, 1.6, 0.03)
    p = [parte(bm, "goma_azul", 0.02), parte(caja(2.0, 1.2, 0.035), "flor_azul", 0.01)]
    mueble("alfombra", p)


def lampara_pie():
    p = [parte(cil((0, 0, 0), (0, 0, 0.05), 0.18, 0.16, 12), "metal", 0.01),
         parte(cil((0, 0, 0.05), (0, 0, 1.4), 0.02, 0.02, 6), "metal", 0),
         parte(cil((0, 0, 1.3), (0, 0, 1.7), 0.26, 0.17, 12), "sombrilla_crema", 0.01),
         parte(bola((0, 0, 1.35), 0.07, sub=2), "luz", 0)]
    mueble("lampara_pie", p)


def maceta():
    p = [parte(cil((0, 0, 0), (0, 0, 0.42), 0.18, 0.24, 12), "tejas", 0.02)] + planta(0, 0, 0.38, 0.3)
    p.append(parte(bola((0.18, -0.1, 0.95), 0.07, sub=1), "flor_amarilla", 0))
    mueble("maceta", p)


def cuadro():
    p = [parte(caja(0.9, 0.05, 0.7, 0, 0, 0), "madera_osc", 0.015),
         parte(caja(0.76, 0.02, 0.56, 0, -0.03, 0.07), "fachada_cielo", 0.0),
         parte(caja(0.76, 0.022, 0.2, 0, -0.035, 0.07), "pasto", 0.0),
         parte(bola((0.2, -0.04, 0.48), 0.06, (1, 0.2, 1), sub=1), "flor_amarilla", 0)]
    mueble("cuadro", p)


def estante_pared():
    p = [parte(caja(1.4, 0.3, 0.05, 0, 0, 0), "madera", 0.012)]
    for sx in (-1, 1):
        p.append(parte(caja(0.04, 0.2, 0.12, sx * 0.55, 0.05, -0.12), "hierro", 0.005))
    p += libros(-0.62, 0.0, 0, 0.05, 0.22)
    p += maceta_chica(0.3, 0, 0.05, 0.08, "blanco")
    mueble("estante_pared", p)


def gato():
    c = "gato_naranja"
    p = [parte(bola((0, 0, 0.13), 0.2, (1.2, 0.8, 0.65), sub=2), c, 0),
         parte(bola((0.2, -0.04, 0.2), 0.11, sub=2), c, 0),
         parte(cil((0.16, -0.08, 0.28), (0.15, -0.08, 0.34), 0.035, 0.0, 4), c, 0),
         parte(cil((0.25, -0.08, 0.28), (0.26, -0.08, 0.34), 0.035, 0.0, 4), c, 0),
         parte(cil((-0.24, 0.02, 0.08), (-0.05, -0.2, 0.06), 0.035, 0.03, 6), c, 0)]
    mueble("gato", p)


def horno():
    w, d, h = 1.2, 1.0, 1.7
    p = [parte(caja(w, d, h, 0, 0, 0), "metal", 0.04),
         parte(caja(w - 0.3, 0.03, 0.5, 0, -d / 2 - 0.005, 0.6), "vidrio_osc", 0.01),
         parte(caja(w - 0.4, 0.035, 0.2, 0, -d / 2 - 0.01, 0.65), "naranja", 0.0),
         parte(caja(w - 0.2, 0.06, 0.05, 0, -d / 2 - 0.03, 1.2), "llanta", 0.01),
         parte(cil((0.35, 0, h), (0.35, 0, h + 0.5), 0.1, 0.1, 8), "cano", 0.01)]
    mueble("horno", p)


def dispenser():
    p = [parte(caja(0.36, 0.36, 1.0, 0, 0, 0), "blanco", 0.03),
         parte(cil((0, 0, 1.0), (0, 0, 1.45), 0.15, 0.15, 12), "agua", 0.02),
         parte(caja(0.08, 0.06, 0.06, -0.07, -0.2, 0.7), "plastico_azul", 0.005),
         parte(caja(0.08, 0.06, 0.06, 0.07, -0.2, 0.7), "plastico_rojo", 0.005)]
    mueble("dispenser", p)


def barril():
    p = [parte(cil((0, 0, 0), (0, 0, 0.45), 0.36, 0.42, 14), "madera", 0.02),
         parte(cil((0, 0, 0.45), (0, 0, 0.9), 0.42, 0.36, 14), "madera", 0.02)]
    for z in (0.12, 0.78):
        p.append(parte(cil((0, 0, z), (0, 0, z + 0.05), 0.4 + (0.015 if z < 0.5 else -0.01), 0.4, 14), "hierro", 0.005))
    mueble("barril", p)


def jaula():
    p = [parte(cil((0, 0, 0), (0, 0, 0.04), 0.22, 0.22, 12), "flor_amarilla", 0.01),
         parte(bola((0, 0, 0.42), 0.22, (1, 1, 0.5), sub=1), "flor_amarilla", 0)]
    for i in range(8):
        a = i * math.pi / 4
        p.append(parte(cil((math.cos(a) * 0.2, math.sin(a) * 0.2, 0.02), (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.42), 0.008, 0.008, 4), "flor_amarilla", 0))
    p.append(parte(cil((-0.15, 0, 0.18), (0.15, 0, 0.18), 0.01, 0.01, 4), "madera", 0))
    p.append(parte(bola((0, 0, 0.25), 0.06, (1.2, 0.8, 1), sub=2), "flor_amarilla", 0))   # Canario
    mueble("jaula", p)


def cajas():
    p = [parte(caja(0.7, 0.6, 0.5, 0, 0, 0), "arena", 0.02), parte(caja(0.5, 0.45, 0.38, 0.05, 0.02, 0.5), "arena", 0.02),
         parte(caja(0.72, 0.1, 0.02, 0, 0, 0.49), "fachada_ocre", 0.0)]
    mueble("cajas", p)


# ================================================================= FACHADA (van pegadas a la pared: el origen está
# en el plano de la pared, abajo al medio; lo que sobresale va hacia -Y, que en Godot es +Z)

def _marco(w, h, prof=0.12, grosor=0.1, color="marco"):
    return [parte(caja(w, prof, grosor, 0, -prof / 2, 0), color, 0.015),
            parte(caja(w, prof, grosor, 0, -prof / 2, h - grosor), color, 0.015),
            parte(caja(grosor, prof, h, -w / 2 + grosor / 2, -prof / 2, 0), color, 0.015),
            parte(caja(grosor, prof, h, w / 2 - grosor / 2, -prof / 2, 0), color, 0.015)]


def ventana_vidrio():
    w, h = 1.2, 1.7
    p = _marco(w, h)
    p.append(parte(caja(w - 0.16, 0.03, h - 0.16, 0, -0.03, 0.08), "vidrio", 0, plano=True))
    p.append(parte(caja(0.05, 0.06, h - 0.16, 0, -0.06, 0.08), "marco", 0.008))           # Parante
    p.append(parte(caja(w - 0.16, 0.06, 0.05, 0, -0.06, h * 0.62), "marco", 0.008))        # Travesaño
    p.append(parte(caja(w + 0.2, 0.24, 0.08, 0, -0.1, -0.07), "cordon", 0.015))             # Alféizar
    p.append(parte(caja(w + 0.06, 0.16, 0.2, 0, -0.09, h), "persiana", 0.02))               # Cajón de persiana
    mueble("ventana_vidrio", p)


def ventana_balcon():
    w, h = 1.2, 2.3
    p = _marco(w, h)
    p.append(parte(caja(w - 0.16, 0.03, h - 0.16, 0, -0.03, 0.08), "vidrio", 0, plano=True))
    p.append(parte(caja(0.05, 0.06, h - 0.16, 0, -0.06, 0.08), "marco", 0.008))
    p.append(parte(caja(1.9, 0.75, 0.12, 0, -0.4, -0.12), "cordon", 0.02))                  # Losa del balcón
    p.append(parte(caja(1.9, 0.05, 0.05, 0, -0.75, 0.88), "hierro", 0.01))                  # Baranda
    for sx in (-1, 1):
        p.append(parte(caja(0.05, 0.75, 0.05, sx * 0.93, -0.4, 0.88), "hierro", 0.01))
    x = -0.9
    while x <= 0.91:
        p.append(parte(cil((x, -0.75, 0.0), (x, -0.75, 0.9), 0.012, 0.012, 4), "hierro", 0))
        x += 0.15
    for sx in (-0.55, 0.55):
        p.append(parte(caja(0.4, 0.16, 0.16, sx, -0.7, 0.93), "tejas", 0.015))
        for i in range(3):
            p.append(parte(bola((sx - 0.12 + i * 0.12, -0.7, 1.13), 0.07, sub=1), ["flor_rosa", "flor_roja", "flor_amarilla"][i], 0))
    mueble("ventana_balcon", p)


def toldo_rayas(nombre, color):
    """Toldo a rayas: arriba pegado a la pared (z 0.6) y el borde de adelante 1,2 m afuera (z 0)."""
    p = []
    n, w = 8, 3.6
    for i in range(n):
        x0, x1 = -w / 2 + w * i / n, -w / 2 + w * (i + 1) / n
        bm = bmesh.new()
        vs = [bm.verts.new(v) for v in ((x0, 0, 0.6), (x1, 0, 0.6), (x1, -1.2, 0.0), (x0, -1.2, 0.0))]
        bm.faces.new(vs)
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.04)
        c = color if i % 2 == 0 else "blanco"
        p.append(parte(bm, c, 0, plano=True))
        p.append(parte(caja(x1 - x0, 0.03, 0.22, (x0 + x1) / 2, -1.2, -0.22), c, 0.006))   # Faldón
    for sx in (-1, 1):
        p.append(parte(cil((sx * 1.7, 0, 0.1), (sx * 1.7, -1.18, 0.02), 0.018, 0.018, 4), "hierro", 0))
    mueble(nombre, p)


def puerta_local():
    w, h = 1.2, 2.6
    p = _marco(w + 0.2, h + 0.1)
    p.append(parte(caja(w - 0.02, 0.06, h - 0.05, 0, -0.04, 0.0), "madera_osc", 0.015))
    p.append(parte(caja(w - 0.4, 0.07, 0.9, 0, -0.05, h - 1.3), "vidrio", 0.005))
    p.append(parte(caja(0.05, 0.08, 0.25, w / 2 - 0.18, -0.09, 1.0), "llanta", 0.01))          # Picaporte
    p.append(parte(caja(w + 0.5, 0.45, 0.14, 0, -0.22, -0.14), "cordon", 0.02))               # Escalón
    p.append(parte(bola((0, -0.16, h + 0.32), 0.09, sub=2), "luz", 0))                        # Farolito
    p.append(parte(caja(0.08, 0.16, 0.06, 0, -0.08, h + 0.2), "hierro", 0.005))
    mueble("puerta_local", p)


# ================================================================= INTERIOR (también pegados a la pared)

def aplique():
    p = [parte(caja(0.14, 0.03, 0.22, 0, -0.015, 0), "llanta", 0.01),
         parte(cil((0, -0.03, 0.12), (0, -0.18, 0.16), 0.015, 0.015, 6), "llanta", 0),
         parte(cil((0, -0.2, 0.1), (0, -0.2, 0.3), 0.13, 0.07, 10), "sombrilla_crema", 0.01),
         parte(bola((0, -0.2, 0.14), 0.05, sub=2), "luz", 0)]
    mueble("aplique", p)


def cortina(nombre, color):
    """Paño con pliegues colgado de un barral (ancho 0,7, alto 2,8)."""
    bm = bmesh.new()
    n, w, h = 10, 0.7, 2.7
    abajo, arriba = [], []
    for i in range(n + 1):
        x = -w / 2 + w * i / n
        y = -0.06 - math.sin(i * math.pi / 2.5) * 0.05
        abajo.append(bm.verts.new((x, y, 0.0)))
        arriba.append(bm.verts.new((x, y, h)))
    for i in range(n):
        bm.faces.new((abajo[i], abajo[i + 1], arriba[i + 1], arriba[i]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.03)
    p = [parte(bm, color, 0, plano=False),
         parte(cil((-w / 2 - 0.05, -0.06, h + 0.06), (w / 2 + 0.05, -0.06, h + 0.06), 0.02, 0.02, 6), "madera_osc", 0),
         parte(caja(w * 0.7, 0.13, 0.08, 0, -0.07, h * 0.42), color, 0.02)]                  # Lazo que la recoge
    mueble(nombre, p)


def salame_suelto():
    p = [parte(cil((0, 0, 0), (0, 0, 0.32), 0.06, 0.055, 10), "remate_marron", 0.02),
         parte(cil((0, 0, 0.32), (0, 0, 0.38), 0.01, 0.01, 4), "letrero_crema", 0)]
    mueble("salame_suelto", p)


# ================================================================= construir y exportar
for f in (biblioteca, estante_panes, torre_macetas, archivero, planta_alta, heladera_vitrina, lampara_verde,
          canasto_panes, sabana, ventilador, salames, mesa_lectura, mostrador_torta, mesa_mate, escritorio_pc,
          mostrador_quesos, silla, mesa_ratona, alfombra, lampara_pie, maceta, cuadro, estante_pared, gato,
          horno, dispenser, barril, jaula, cajas):
    f()
sillon("sillon_azul", "goma_azul")
sillon("sillon_amarillo", "toldo_amarillo")
for f in (ventana_vidrio, ventana_balcon, puerta_local, aplique, salame_suelto):
    f()
for c in ("rojo", "verde", "azul", "amarillo"):
    toldo_rayas("toldo_rayas_" + c, "toldo_" + c)
for nombre, c in (("cortina_roja", "toldo_rojo"), ("cortina_azul", "goma_azul"), ("cortina_verde", "toldo_verde"), ("cortina_crema", "sombrilla_crema")):
    cortina(nombre, c)

for o in list(COL_TRABAJO.objects):
    bpy.data.objects.remove(o)

medidas = {}
for n, o in ASSETS.items():
    bb = [Vector(c) for c in o.bound_box]
    mn = Vector((min(p.x for p in bb), min(p.y for p in bb), min(p.z for p in bb)))
    mx = Vector((max(p.x for p in bb), max(p.y for p in bb), max(p.z for p in bb)))
    # En Godot: X igual, Y = Z de Blender, Z = -Y de Blender
    medidas[n] = (mx.x - mn.x, mx.z - mn.z, mx.y - mn.y, mn.z, mx.z)
    _activar([o])
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, n + ".glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="NONE",
                              export_cameras=False, export_lights=False)

# Las medidas para Godot (world/muebles_datos.gd): tamaño y altura de la base y del tope
with open(os.path.join(ROOT, "world", "muebles_datos.gd"), "w", encoding="utf-8") as f:
    f.write("class_name MueblesDatos\nextends RefCounted\n## Lo escribe tools/blender/generar_muebles.py: no editar a mano.\n")
    f.write("## Por mueble: tamaño (X, Y, Z de Godot), y de abajo y y de arriba.\n\nconst PIEZAS := {\n")
    for n in sorted(medidas):
        sx, sy, sz, y0, y1 = medidas[n]
        tris = sum(len(p.vertices) - 2 for p in ASSETS[n].data.polygons)
        f.write('\t"%s": {"tam": Vector3(%.3f, %.3f, %.3f), "y0": %.3f, "y1": %.3f, "tris": %d},\n' % (n, sx, sy, sz, y0, y1, tris))
    f.write("}\n")


# ================================================================= vitrina
def preparar_render():
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            SCENE.render.engine = eng
            break
        except TypeError:
            pass
    SCENE.render.resolution_x = 1600
    SCENE.render.resolution_y = 900
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
    so = bpy.data.objects.new("sol", sol)
    so.rotation_euler = (math.radians(42), 0, math.radians(-35))
    SCENE.collection.objects.link(so)
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    co = bpy.data.objects.new("cam", cam)
    SCENE.collection.objects.link(co)
    SCENE.camera = co
    return co


if HACER_RENDER:
    cam = preparar_render()
    col = bpy.data.collections.new("Vitrina")
    SCENE.collection.children.link(col)
    COL_PIEZAS.hide_render = True
    objs = []
    nombres = sorted(ASSETS)
    for i, n in enumerate(nombres):
        fila, c = divmod(i, 8)
        o = bpy.data.objects.new(n + "_v", ASSETS[n].data)
        o.location = (c * 2.8, -fila * 3.2, 0)
        o.rotation_euler = (0, 0, math.radians(-20))
        col.objects.link(o)
        objs.append(o)
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    centro = sum(pts, Vector()) / len(pts)
    az, el = math.radians(-60), math.radians(32)
    d = Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el)))
    cam.location = centro + d * 100
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = 26
    SCENE.render.filepath = os.path.join(DIR_PREVIAS, "muebles.png")
    bpy.ops.render.render(write_still=True)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_FUENTE, "muebles.blend"))
print("MUEBLES_OK", len(ASSETS))
