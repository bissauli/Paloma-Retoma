# Generador del kit de la ciudad (mismo estilo que el kit del parque: paleta única con degradés,
# bordes biselados y follaje facetado). Edificios porteños, mobiliario urbano, juegos de plaza,
# parque de perros, barrio enemigo y algunas piezas especiales.
#
# Uso (sin abrir Blender):
#   F:/blender.exe -b --factory-startup -P tools/blender/generar_ciudad.py -- [--sin-render] [--sin-export]
#
# Salida:
#   modelos/ciudad/piezas/*.glb      props (origen en el centro de la base, frente hacia -Y = +Z en Godot)
#   modelos/ciudad/edificios/*.glb   edificios (origen en el medio de la línea de fachada, a nivel del piso;
#                                    el edificio sigue hacia +Y = -Z en Godot)
#                                    esquinas: origen en el cruce de las dos líneas de fachada, el edificio
#                                    ocupa +X/+Y y sus fachadas miran a -Y y -X (+Z y -X en Godot)
#   modelos/ciudad/kit_datos.gd      paleta, medidas, colisiones y lugares para carteles de cada pieza
#   modelos/ciudad/fuente/           ciudad.blend + paleta (ignorado por Godot)
#   modelos/ciudad/previas/          renders de vista previa (ignorado por Godot)
#
# Los GLB se exportan sin material: Godot les pone uno solo, compartido, con la paleta que arma a
# partir de kit_datos.gd (así todo se puede fusionar en pocas mallas).

import bpy, bmesh, math, random, os, sys
import numpy as np
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "modelos", "ciudad")
DIR_PIEZAS = os.path.join(OUT, "piezas")
DIR_EDIF = os.path.join(OUT, "edificios")
DIR_FUENTE = os.path.join(OUT, "fuente")
DIR_PREVIAS = os.path.join(OUT, "previas")
ARCHIVO_DATOS = os.path.join(OUT, "kit_datos.gd")

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
HACER_RENDER = "--sin-render" not in args
HACER_EXPORT = "--sin-export" not in args

for d in (DIR_PIEZAS, DIR_EDIF, DIR_FUENTE, DIR_PREVIAS):
    os.makedirs(d, exist_ok=True)
for d in (DIR_FUENTE, DIR_PREVIAS):
    open(os.path.join(d, ".gdignore"), "w").close()

bpy.ops.wm.read_factory_settings(use_empty=True)
SCENE = bpy.context.scene

# ---------------------------------------------------------------- paleta (8x8 celdas con degradé)
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


IMG = imagen_paleta("ciudad_paleta")
IMG_EM = imagen_paleta("ciudad_emision", solo={"luz"})


def material():
    mat = bpy.data.materials.new("ciudad")
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


def coleccion(nombre, padre=None):
    c = bpy.data.collections.new(nombre)
    (padre or SCENE.collection).children.link(c)
    return c


COL_TRABAJO = coleccion("Trabajo")
COL_PIEZAS = coleccion("Piezas")
COL_EDIF = coleccion("Edificios")
ASSETS = {}
DATOS = {}

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


def bm_blob(c, r, sc=(1, 1, 1), sub=1, jitter=0.0, rng=None):
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


def bm_perfil_x(pts_yz, x0, x1):
    """Perfil en el plano YZ extruido a lo largo de X (techos a dos aguas, mansardas, rampas)."""
    bm = bm_prisma(pts_yz, x0, x1)
    A = Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    bmesh.ops.transform(bm, matrix=A, verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def bm_perfil_y(pts_xz, y0, y1):
    """Perfil en el plano XZ extruido a lo largo de Y (frontones que miran hacia -Y)."""
    bm = bm_prisma(pts_xz, y0, y1)
    A = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    bmesh.ops.transform(bm, matrix=A, verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def bm_aro(ext, inn, z0, z1):
    """Borde entre dos contornos con la misma cantidad de puntos (cordón alrededor de un piso)."""
    bms = []
    n = len(ext)
    for i in range(n):
        j = (i + 1) % n
        bms.append(bm_prisma([ext[i], ext[j], inn[j], inn[i]], z0, z1))
    return bms


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


def bm_torno(perfil, seg=12, cx=0, cy=0, tapas=True):
    """Sólido de revolución: perfil [(radio, z)] de abajo hacia arriba (radio 0 = punta)."""
    bm = bmesh.new()
    anillos = []
    for r, z in perfil:
        if r < 1e-6:
            anillos.append([bm.verts.new((cx, cy, z))])
        else:
            anillos.append([bm.verts.new((cx + r * math.cos(2 * math.pi * i / seg), cy + r * math.sin(2 * math.pi * i / seg), z))
                            for i in range(seg)])
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


def transformar(bm, M):
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    if M.to_3x3().determinant() < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    return bm


def circulo(r, seg=32, cx=0, cy=0):
    return [(cx + r * math.cos(2 * math.pi * i / seg), cy + r * math.sin(2 * math.pi * i / seg)) for i in range(seg)]


# ---------------------------------------------------------------- pintura (UV a la paleta)


def P(bm, color, z0=None, z1=None):
    """Pinta un elemento con el degradé de su color, de abajo (oscuro) hacia arriba (claro).
    El degradé usa la altura propia del elemento, o z0..z1 si se pasan."""
    i = PIDX[color]
    uvl = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    zs = [v.co.z for v in bm.verts]
    lo = min(zs) if z0 is None else z0
    hi = max(zs) if z1 is None else z1
    span = max(hi - lo, 1e-4)
    cx, cy = i % CELLS, i // CELLS
    u = (cx + 0.5) / CELLS
    for f in bm.faces:
        for l in f.loops:
            t = min(max((l.vert.co.z - lo) / span, 0.0), 1.0)
            l[uvl].uv = (u, (cy + MARGEN + t * (1 - 2 * MARGEN)) / CELLS)
    return bm


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


ANGULO_BISEL = math.radians(40)


def obj(bms, bisel=0.0, seg=1, nombre="parte"):
    """Objeto con los elementos ya pintados. bisel>0 redondea las aristas vivas (como KayKit);
    sin bisel queda con sombreado plano (facetado)."""
    bms = [b for b in (bms if isinstance(bms, (list, tuple)) else [bms]) if b is not None]
    if not bms:
        return None
    bm = _merge(bms)
    bm.normal_update()
    if bisel > 0:
        peso = bm.edges.layers.float.new("bevel_weight_edge")
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0) > ANGULO_BISEL:
                e[peso] = 1.0
    me = bpy.data.meshes.new(nombre)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nombre, me)
    COL_TRABAJO.objects.link(o)
    for p in me.polygons:
        p.use_smooth = bisel > 0
    if bisel > 0:
        mod = o.modifiers.new("bisel", "BEVEL")
        mod.width = bisel
        mod.segments = seg
        mod.limit_method = "WEIGHT"
        mod.harden_normals = True
        _activar([o])
        bpy.ops.object.modifier_apply(modifier=mod.name)
    me.materials.clear()
    me.materials.append(MAT)
    return o


# ---------------------------------------------------------------- datos para Godot (colisiones, carteles)


class Col:
    def __init__(self):
        self.cajas, self.esferas, self.convexos, self.carteles = [], [], [], []


COL = Col()


def empezar():
    global COL
    COL = Col()


def col_caja(c, s, base=None):
    COL.cajas.append((Vector(c), Vector(s), (base if base is not None else Matrix.Identity(3)).copy()))


def col_esfera(c, r):
    COL.esferas.append((Vector(c), r))


def col_convexo(puntos):
    COL.convexos.append([Vector(p) for p in puntos])


def col_prisma(pts2d, z0, z1):
    col_convexo([(x, y, z0) for x, y in pts2d] + [(x, y, z1) for x, y in pts2d])


def cartel(p, n, ancho, alto, tipo="local"):
    COL.carteles.append((Vector(p), Vector(n).normalized(), ancho, alto, tipo))


def unir(objs, nombre, coleccion_dest, carpeta, sombra=True, rango=0.0):
    objs = [o for o in objs if o]
    _activar(objs)
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = nombre
    o.data.name = nombre
    COL_TRABAJO.objects.unlink(o)
    coleccion_dest.objects.link(o)
    ASSETS[nombre] = o
    DATOS[nombre] = {"carpeta": carpeta, "sombra": sombra, "rango": rango, "col": COL}
    empezar()
    return o


def pieza(objs, nombre, sombra=True, rango=0.0):
    return unir(objs, nombre, COL_PIEZAS, "piezas", sombra, rango)


def edif(objs, nombre):
    return unir(objs, nombre, COL_EDIF, "edificios", True, 0.0)


# ---------------------------------------------------------------- fachadas

UP = Vector((0, 0, 1))


class Frente:
    """Marco local de una fachada: u a lo largo (0 en el centro), n hacia afuera, z arriba."""

    def __init__(self, centro, normal, ancho):
        n = Vector((normal[0], normal[1], 0)).normalized()
        t = n.cross(UP)
        self.n, self.t, self.w = n, t, ancho
        c = Vector((centro[0], centro[1], 0))
        self.c = c
        self.M = Matrix(((t.x, n.x, 0, c.x), (t.y, n.y, 0, c.y), (0, 0, 1, 0), (0, 0, 0, 1)))

    def caja(self, u, z, w, h, d, off=0.0):
        """Caja de ancho w (a lo largo), alto h desde z, que sale d desde 'off' metros de la pared."""
        bm = bm_box(w, d, h, u, off + d / 2, z)
        bmesh.ops.transform(bm, matrix=self.M, verts=bm.verts)
        return bm

    def local(self, bm):
        bmesh.ops.transform(bm, matrix=self.M, verts=bm.verts)
        return bm

    def punto(self, u, off, z=0.0):
        return self.M @ Vector((u, off, z))

    def col(self, u, z, w, h, d, off=0.0):
        col_caja(self.M @ Vector((u, off + d / 2, z + h / 2)), (w, d, h), self.M.to_3x3())

    def cartel(self, u, z, w, h, off, tipo="local"):
        cartel(self.punto(u, off, z), self.n, w, h, tipo)


PB = 4.2        # alto de la planta baja
PISO = 3.0      # alto de cada piso
PRETIL = 1.0    # pretil de la azotea


def ventana(F, u, z, w, h, rng, persiana=0.75, marco="marco", alfeizar=True):
    out = [P(F.caja(u, z - 0.08, w + 0.16, h + 0.16, 0.05), marco),
           P(F.caja(u, z, w, h, 0.07), "vidrio"),
           P(F.caja(u, z, 0.06, h, 0.09), marco)]
    if w > 1.4:
        out.append(P(F.caja(u - w / 4, z, 0.05, h, 0.085), marco))
        out.append(P(F.caja(u + w / 4, z, 0.05, h, 0.085), marco))
    if rng.random() < persiana:
        hp = h * rng.choice((0.15, 0.3, 0.45, 0.6, 1.0))
        out.append(P(F.caja(u, z + h - hp, w, hp, 0.095), "persiana"))
    if alfeizar:
        out.append(P(F.caja(u, z - 0.14, w + 0.3, 0.08, 0.16), "piedra"))
    return out


def baranda(F, u, z, w, off, alto=0.95, sep=0.22, color="hierro", lados=0.0):
    """Baranda de hierro de ancho w a 'off' metros de la pared. lados>0: también los costados."""
    bms = [F.caja(u, z + alto - 0.05, w, 0.05, 0.05, off - 0.025), F.caja(u, z + 0.1, w, 0.04, 0.04, off - 0.02)]
    n = max(2, int(round(w / sep)))
    for i in range(n + 1):
        bms.append(F.caja(u - w / 2 + i * w / n, z, 0.03, alto, 0.03, off - 0.015))
    if lados > 0:
        for s in (-1, 1):
            bms.append(F.caja(u + s * w / 2, z + alto - 0.05, 0.05, 0.05, lados, 0))
            for k in range(1, 3):
                bms.append(F.caja(u + s * w / 2, z, 0.03, alto, 0.03, lados * k / 3 - 0.015))
    return [P(b, color) for b in bms]


def aire(F, u, z, off=0.0):
    return [P(F.caja(u, z, 0.82, 0.56, 0.3, off), "blanco"),
            P(F.caja(u + 0.12, z + 0.08, 0.44, 0.4, 0.02, off + 0.3), "persiana"),
            P(F.caja(u - 0.3, z + 0.12, 0.1, 0.3, 0.02, off + 0.3), "persiana")]


def maceta_balcon(F, u, z, off, rng):
    p = F.punto(u, off, z)
    return [P(bm_box(0.4, 0.4, 0.35, p.x, p.y, z), "tejas"),
            P(bm_blob((p.x, p.y, z + 0.55), 0.32, (1, 1, 0.9), 2, 0.08, rng), "hoja")]


def toldo(F, u, w, z_arriba, largo, caida, colores, rayas=1, col=True):
    """Toldo inclinado que sale de la pared a z_arriba y baja 'caida' en 'largo' metros."""
    ang = math.atan2(caida, largo)
    L = math.hypot(largo, caida)
    R = Matrix.Rotation(-ang, 4, "X")
    T = F.M @ Matrix.Translation((0, 0, z_arriba)) @ R
    out = []
    k = max(1, rayas)
    for i in range(k):
        ww = w / k
        uu = u - w / 2 + ww * (i + 0.5)
        c = colores[i % len(colores)]
        bm = bm_box(ww, L, 0.05, uu, L / 2, -0.025)
        bmesh.ops.transform(bm, matrix=T, verts=bm.verts)
        out.append(P(bm, c))
        out.append(P(F.caja(uu, z_arriba - caida - 0.3, ww, 0.32, 0.03, largo - 0.03), c))
    for s in (-1, 1):
        out.append(P(F.caja(u + s * (w / 2 - 0.05), z_arriba - caida - 0.05, 0.04, 0.04, largo, 0), "hierro"))
    if col:
        centro = T @ Vector((u, L / 2, -0.025))
        col_caja(centro, (w, L, 0.08), T.to_3x3())
    return out


def tanque(x, y, z, r=0.6, h=1.25, base=True):
    out = []
    z1 = z
    if base:
        out.append(P(bm_box(r * 2 + 0.3, r * 2 + 0.3, 0.45, x, y, z), "piedra_osc"))
        z1 = z + 0.45
    out.append(P(bm_cyl((x, y, z1), (x, y, z1 + h), r, r, 12), "tanque"))
    out.append(P(bm_torno([(r + 0.04, z1 + h), (r * 0.8, z1 + h + 0.18), (0.14, z1 + h + 0.28), (0, z1 + h + 0.3)], 12, x, y),
                 "tanque"))
    col_caja((x, y, (z + z1 + h + 0.3) / 2), (r * 2 + 0.3, r * 2 + 0.3, z1 + h + 0.3 - z))
    return out


def antena(x, y, z, alto=3.0):
    out = [bm_cyl((x, y, z), (x, y, z + alto), 0.035, 0.025, 6)]
    for k, a in enumerate((0.75, 0.55, 0.4)):
        zz = z + alto * (0.55 + k * 0.15)
        out.append(bm_cyl((x - a, y, zz), (x + a, y, zz), 0.018, 0.018, 4))
    return [P(b, "metal") for b in out]


def tendedero(x, y, z, largo=3.0, rng=None, rot=0.0):
    rng = rng or random.Random(7)
    R = Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(rot), 4, "Z")
    out = []
    for s in (-1, 1):
        out.append(P(transformar(bm_cyl((s * largo / 2, 0, 0), (s * largo / 2, 0, 1.7), 0.03, 0.03, 6), R), "metal"))
    out.append(P(transformar(bm_cyl((-largo / 2, 0, 1.62), (largo / 2, 0, 1.62), 0.01, 0.01, 4), R), "blanco"))
    colores = ["toldo_rojo", "toldo_azul", "blanco", "toldo_amarillo", "plastico_verde", "flor_rosa"]
    x0 = -largo / 2 + 0.3
    while x0 < largo / 2 - 0.4:
        w = rng.uniform(0.3, 0.6)
        h = rng.uniform(0.35, 0.7)
        out.append(P(transformar(bm_box(w, 0.02, h, x0 + w / 2, 0, 1.6 - h), R), rng.choice(colores)))
        x0 += w + rng.uniform(0.08, 0.25)
    return out


def plantas_azotea(x0, x1, y0, y1, z, rng):
    """Terraza con macetas y una pérgola (como las azoteas porteñas con plantas)."""
    est, det = [], []
    n = rng.randint(3, 6)
    for _ in range(n):
        x = rng.uniform(x0 + 0.5, x1 - 0.5)
        y = rng.uniform(y0 + 0.5, y1 - 0.5)
        s = rng.uniform(0.7, 1.2)
        det.append(P(bm_box(0.5 * s, 0.5 * s, 0.4 * s, x, y, z), rng.choice(("tejas", "blanco", "piedra"))))
        det.append(P(bm_blob((x, y, z + 0.4 * s + 0.3 * s), 0.38 * s, (1, 1, 0.95), 2, 0.08, rng), rng.choice(("hoja", "hoja_osc"))))
    if x1 - x0 > 4 and y1 - y0 > 3 and rng.random() < 0.6:
        px, py = (x0 + x1) / 2, (y0 + y1) / 2
        madera = []
        for sx in (-1, 1):
            for sy in (-1, 1):
                madera.append(bm_box(0.12, 0.12, 2.3, px + sx * 1.3, py + sy * 1.0, z))
        for sy in (-1, 1):
            madera.append(bm_box(2.9, 0.1, 0.12, px, py + sy * 1.0, z + 2.3))
        for k in range(6):
            madera.append(bm_box(0.08, 2.4, 0.08, px - 1.25 + k * 0.5, py, z + 2.42))
        est += [P(b, "madera") for b in madera]
        det.append(P(bm_blob((px + 1.3, py - 1.0, z + 2.4), 0.45, (1, 1, 0.6), 2, 0.1, rng), "hoja"))
        det.append(P(bm_box(1.6, 0.7, 0.42, px, py, z), "madera"))
    return est, det


def azotea(x0, x1, y0, y1, H, rng, pisos, verde=0.35):
    """Lo que hay arriba de la azotea: sala de máquinas, tanques, antenas, plantas o tendederos."""
    est, det = [], []
    ancho = x1 - x0
    cx = rng.uniform(x0 + 2.0, x1 - 2.0) if ancho > 4.5 else (x0 + x1) / 2
    cy = y1 - 2.2
    if pisos >= 5:
        est.append(P(bm_box(3.0, 3.2, 2.4, cx, cy, H), "medianera"))
        col_caja((cx, cy, H + 1.2), (3.0, 3.2, 2.4))
        det += tanque(cx, cy, H + 2.4, base=False)
    else:
        det += tanque(cx, cy, H)
    if rng.random() < 0.55:
        det += antena(rng.uniform(x0 + 0.6, x1 - 0.6), rng.uniform(y0 + 1, y1 - 4), H)
    r = rng.random()
    if r < verde:
        e, d = plantas_azotea(x0 + 0.3, x1 - 0.3, y0 + 0.4, min(y1 - 4.5, y0 + 6), H, rng)
        est += e
        det += d
    elif r < verde + 0.3 and ancho > 4:
        det += tendedero((x0 + x1) / 2, y0 + 2.5, H, min(ancho - 1.2, 4.0), rng)
    return est, det


# ---------------------------------------------------------------- planta baja

COLORES_TOLDO = ["toldo_rojo", "toldo_verde", "toldo_azul", "toldo_amarillo", "toldo_naranja"]


def planta_baja(F, tipo, fachada, rng, toldo_col=None, rayas=0, cartel_col=None):
    """Planta baja sobre la fachada F (ancho F.w): local con vidriera, persiana, cartel y toldo;
    entrada de edificio; o garaje."""
    W = F.w
    est, det = [], []
    det.append(P(F.caja(0, 0, W, 0.6, 0.06), "piedra_osc"))   # zócalo
    if tipo in ("local", "cafe"):
        al = W - 1.3
        for s in (-1, 1):
            est.append(P(F.caja(s * (W / 2 - 0.32), 0, 0.64, PB - 0.15, 0.14), fachada, 0, PB))
        det.append(P(F.caja(0, 0.12, al, 2.9, 0.03), "sombra"))
        det.append(P(F.caja(0, 0.62, al - 0.2, 2.3, 0.05), "vidrio_osc"))
        det.append(P(F.caja(0, 0.12, al, 0.5, 0.07), "piedra"))
        k = max(2, int(al / 1.6))
        for i in range(k + 1):
            det.append(P(F.caja(-al / 2 + i * al / k, 0.12, 0.07, 2.9, 0.08), "hierro"))
        if tipo == "local" and rng.random() < 0.6:
            hp = rng.uniform(0.5, 2.6)
            det.append(P(F.caja(0, 3.02 - hp, al, hp, 0.09), "persiana"))
            for j in range(int(hp / 0.28)):
                det.append(P(F.caja(0, 3.02 - hp + 0.14 + j * 0.28, al, 0.025, 0.1), "piedra_osc"))
        det.append(P(F.caja(0, 3.02, al + 0.2, 0.22, 0.13), "piedra"))
        cc = cartel_col or rng.choice(COLORES_TOLDO + ["kiosco", "hierro", "blanco"])
        est.append(P(F.caja(0, 3.24, W - 1.0, 0.72, 0.12), cc))
        F.cartel(0, 3.6, W - 1.4, 0.55, 0.125, "local")
        if toldo_col:
            cols = [toldo_col, "blanco"] if rayas else [toldo_col]
            det += toldo(F, 0, al + 0.4, 3.12, 1.7, 0.65, cols, rayas or 1)
    elif tipo == "entrada":
        det.append(P(F.caja(0, 0, 2.1, 3.3, 0.12), "piedra"))
        det.append(P(F.caja(0, 0.0, 1.6, 3.0, 0.16), "madera" if rng.random() < 0.6 else "hierro"))
        det.append(P(F.caja(0, 1.4, 1.1, 1.3, 0.18), "vidrio_osc"))
        det += baranda(F, 0, 1.4, 1.1, 0.2, alto=1.3, sep=0.18)
        det.append(P(F.caja(0.6, 1.35, 0.08, 0.2, 0.22), "luz"))
        bays = max(0, int((W - 2.4) / 2.4))
        for s in (-1, 1):
            for b in range(bays // 2):
                u = s * (1.6 + 0.9 + b * 2.3)
                if abs(u) + 0.7 > W / 2:
                    continue
                det += ventana(F, u, 1.0, 1.2, 2.0, rng, 0.5)
                det += baranda(F, u, 1.0, 1.25, 0.17, alto=2.0, sep=0.14)
    elif tipo == "garaje":
        g = min(3.2, W - 1.6)
        det.append(P(F.caja(-W / 2 + 0.6 + g / 2, 0, g + 0.3, 3.0, 0.08), "piedra"))
        det.append(P(F.caja(-W / 2 + 0.6 + g / 2, 0.0, g, 2.8, 0.12), "persiana"))
        for j in range(10):
            det.append(P(F.caja(-W / 2 + 0.6 + g / 2, 0.14 + j * 0.27, g, 0.02, 0.13), "piedra_osc"))
        det.append(P(F.caja(W / 2 - 1.2, 0, 1.1, 2.6, 0.12), "madera"))
    # banda entre la planta baja y el primer piso
    est.append(P(F.caja(0, PB - 0.12, W + 0.08, 0.3, 0.2), "piedra"))
    return est, det


# ---------------------------------------------------------------- pisos


def pisos_fachada(F, pisos, estilo, fachada, rng, z_base=PB, opciones=None):
    """Ventanas, balcones, aires y cornisas de los pisos altos sobre la fachada F."""
    op = opciones or {}
    W = F.w
    est, det = [], []
    bays = max(1, int(round(W / 2.8)))
    bw = W / bays
    us = [-W / 2 + bw * (i + 0.5) for i in range(bays)]
    H = z_base + pisos * PISO
    if estilo == "moderno":
        det.append(P(F.caja(0, z_base, W - 0.5, H - z_base - 0.1, 0.08), "vidrio", z_base, H))
        for f in range(pisos + 1):
            est.append(P(F.caja(0, z_base + f * PISO - 0.22, W - 0.4, 0.42, 0.16), op.get("banda", "piedra")))
        k = max(1, int((W - 0.5) / 1.5))
        for i in range(k + 1):
            det.append(P(F.caja(-(W - 0.5) / 2 + i * (W - 0.5) / k, z_base, 0.07, H - z_base, 0.13), "marco"))
        for s in (-1, 1):
            est.append(P(F.caja(s * (W / 2 - 0.15), 0, 0.3, H + 0.3, 0.22), fachada, 0, H))
        return est, det
    corrido = estilo == "departamentos"
    baranda_maciza = op.get("maciza", rng.random() < 0.5)
    for f in range(pisos):
        z0 = z_base + f * PISO
        if corrido:
            prof = 1.15
            est.append(P(F.caja(0, z0 - 0.02, W - 0.25, 0.16, prof), op.get("losa", "blanco")))
            F.col(0, z0 - 0.02, W - 0.25, 0.16, prof)
            for s in (-1, 1):
                est.append(P(F.caja(s * (W / 2 - 0.2), z0 - 0.02, 0.14, PISO, prof), fachada, z_base, H))
            if baranda_maciza:
                est.append(P(F.caja(0, z0 + 0.14, W - 0.65, 0.9, 0.1, prof - 0.1), op.get("pared_balcon", fachada), z_base, H))
            else:
                det += baranda(F, 0, z0 + 0.14, W - 0.65, prof - 0.05, alto=0.95, sep=0.3)
            for u in us:
                det += ventana(F, u, z0 + 0.2, bw - 0.85, 2.35, rng, 0.85, alfeizar=False)
            if rng.random() < 0.45:
                u = rng.choice(us) + rng.choice((-1, 1)) * (bw / 2 - 0.5)
                det += aire(F, u, z0 + 0.16, 0.35)
            if rng.random() < 0.3:
                det += maceta_balcon(F, rng.choice(us) + 0.6, z0 + 0.16, 0.6, rng)
        else:
            alto_v = 2.25 if estilo == "clasico" else 1.6
            zv = z0 + (0.35 if estilo == "clasico" else 0.8)
            for u in us:
                w = min(1.15, bw - 0.9)
                det += ventana(F, u, zv, w, alto_v, rng, 0.7)
                if estilo == "clasico":
                    det.append(P(F.caja(u, zv + alto_v + 0.12, w + 0.5, 0.18, 0.14), "piedra"))
                    if op.get("balcones", True) and (f == 0 or rng.random() < 0.65):
                        est.append(P(F.caja(u, z0 + 0.2, w + 0.7, 0.14, 0.6), "piedra"))
                        F.col(u, z0 + 0.2, w + 0.7, 0.14, 0.6)
                        det += baranda(F, u, z0 + 0.34, w + 0.6, 0.55, alto=0.9, sep=0.26, lados=0.55)
                else:
                    det.append(P(F.caja(u, zv + alto_v + 0.1, w + 0.3, 0.2, 0.1), "piedra"))
                    if rng.random() < 0.25:
                        det += aire(F, u + w / 2 + 0.6 if abs(u + w / 2 + 0.6) + 0.45 < W / 2 else u, zv - 0.75, 0.0)
            if estilo == "clasico" and f < pisos - 1:
                det.append(P(F.caja(0, z0 + PISO - 0.08, W, 0.12, 0.08), "piedra"))
    return est, det


def remate(F, H, estilo, fachada, rng, balaustrada=False):
    """Cornisa y pretil del frente."""
    W = F.w
    est, det = [], []
    if estilo == "clasico":
        est.append(P(F.caja(0, H - 0.05, W + 0.4, 0.38, 0.5), "piedra"))
        for i in range(int(W / 0.5)):
            det.append(P(F.caja(-W / 2 + 0.25 + i * 0.5, H - 0.2, 0.14, 0.16, 0.12, 0.0), "piedra"))
        if balaustrada:
            est.append(P(F.caja(0, H + 0.33, W, 0.16, 0.36), "piedra"))
            est.append(P(F.caja(0, H + 0.92, W + 0.1, 0.14, 0.4), "piedra"))
            n = int(W / 0.38)
            for i in range(n):
                det.append(P(F.local(bm_box(0.11, 0.11, 0.43, -W / 2 + 0.19 + i * W / n, 0.18, H + 0.49)), "piedra"))
            F.col(0, H, W, 1.06, 0.4)
            return est, det
    elif estilo == "moderno":
        est.append(P(F.caja(0, H - 0.1, W, 0.5, 0.22), "piedra"))
    else:
        est.append(P(F.caja(0, H - 0.08, W + 0.2, 0.25, 0.28), "piedra"))
    return est, det


# ---------------------------------------------------------------- edificios


def lejos(nombre, frentes, base, H, pisos, estilo, toldo_col=None):
    """Versión simple de un edificio para verlo de lejos (Godot la cambia por la detallada a más de
    ~120 m, y el horizonte usa sólo esta): el mismo volumen, una caja por ventana, la planta baja, el
    toldo, la cornisa y lo de la azotea que pase en "base". Sin biseles: unas 10 veces menos caras."""
    empezar()
    bms = list(base)
    for F in frentes:
        W = F.w
        if estilo == "barrio":
            bms.append(P(F.caja(-W / 2 + 0.5 + min(2.8, W * 0.38) / 2, 0, min(2.8, W * 0.38), 2.4, 0.08), "chapa"))
            for p in range(pisos):
                bms.append(P(F.caja(0.8 if p == 0 else 0.0, 0.3 + p * 3.0 + 1.0, 1.1, 1.2, 0.07), "vidrio"))
            continue
        bms.append(P(F.caja(0, 0.1, W - 0.9, 3.0, 0.05), "vidrio_osc"))
        if toldo_col:
            bms.append(P(F.caja(0, 2.45, W - 0.9, 0.65, 1.3), toldo_col))
        bms.append(P(F.caja(0, PB - 0.12, W + 0.08, 0.3, 0.2), "piedra"))
        if estilo == "moderno":
            bms.append(P(F.caja(0, PB, W - 0.5, H - PB - 0.1, 0.08), "vidrio", PB, H))
            for f in range(pisos + 1):
                bms.append(P(F.caja(0, PB + f * PISO - 0.22, W - 0.4, 0.42, 0.16), "piedra"))
        else:
            bays = max(1, int(round(W / 2.8)))
            bw = W / bays
            dep = estilo == "departamentos"
            for f in range(pisos):
                z0 = PB + f * PISO
                if dep:
                    bms.append(P(F.caja(0, z0 - 0.02, W - 0.25, 0.16, 1.15), "blanco"))
                for i in range(bays):
                    u = -W / 2 + bw * (i + 0.5)
                    w = bw - 0.85 if dep else min(1.15, bw - 0.9)
                    alto = 2.35 if dep else (2.25 if estilo == "clasico" else 1.6)
                    zv = z0 + (0.2 if dep else (0.35 if estilo == "clasico" else 0.8))
                    bms.append(P(F.caja(u, zv, w, alto, 0.07), "vidrio"))
        bms.append(P(F.caja(0, H - 0.08, W + 0.2, 0.3, 0.3), "piedra"))
    edif([obj(bms)], nombre + "_lejos")
    DATOS[nombre + "_lejos"]["tipo"] = "lejos"


def _techo_lejos(x, y, H, pisos):
    """Sala de máquinas y tanque (o sólo el tanque) en versión simple."""
    if pisos >= 5:
        return [P(bm_box(3.0, 3.2, 2.4, x, y, H), "medianera"), P(bm_cyl((x, y, H + 2.4), (x, y, H + 3.7), 0.6, 0.6, 8), "tanque")]
    return [P(bm_box(1.5, 1.5, 0.45, x, y, H), "piedra_osc"), P(bm_cyl((x, y, H + 0.45), (x, y, H + 1.8), 0.6, 0.6, 8), "tanque")]


def edificio(nombre, W, D, pisos, estilo, fachada, seed, pb="local", toldo_col=None, rayas=0,
             techo="plano", opciones=None, cartel_col=None):
    """Edificio entre medianeras: fachada en y=0 mirando a -Y, de x=-W/2 a W/2, fondo hasta y=D."""
    empezar()
    rng = random.Random(seed)
    H = PB + pisos * PISO
    F = Frente((0, 0), (0, -1), W)
    est = [P(bm_box(W, 0.6, H, 0, 0.3, 0), fachada, 0, H),
           P(bm_box(W - 0.04, D - 0.6, H, 0, 0.6 + (D - 0.6) / 2, 0), "medianera", 0, H)]
    col_caja((0, D / 2, H / 2), (W, D, H))
    det = []
    e, d = planta_baja(F, pb, fachada, rng, toldo_col, rayas, cartel_col)
    est += e
    det += d
    e, d = pisos_fachada(F, pisos, estilo, fachada, rng, PB, opciones)
    est += e
    det += d
    con_mansarda = techo == "mansarda"
    bal = con_mansarda or (estilo == "clasico" and rng.random() < 0.5)
    e, d = remate(F, H, estilo, fachada, rng, balaustrada=bal)
    est += e
    det += d
    # Azotea: losa y pretil (el frente, si no hay balaustrada, del color de la fachada)
    det.append(P(bm_box(W - 0.4, D - 0.4, 0.06, 0, D / 2, H), "azotea"))
    e0 = 0.25
    if not bal:
        est.append(P(bm_box(W, e0, PRETIL, 0, e0 / 2, H), fachada, 0, H + PRETIL))
        col_caja((0, e0 / 2, H + PRETIL / 2), (W, e0, PRETIL))
    est.append(P(bm_box(W, e0, PRETIL, 0, D - e0 / 2, H), "medianera"))
    for s in (-1, 1):
        est.append(P(bm_box(e0, D - 2 * e0, PRETIL, s * (W / 2 - e0 / 2), D / 2, H), "medianera"))
        col_caja((s * (W / 2 - e0 / 2), D / 2, H + PRETIL / 2), (e0, D - 2 * e0, PRETIL))
    col_caja((0, D - e0 / 2, H + PRETIL / 2), (W, e0, PRETIL))
    if con_mansarda:
        e, d = mansarda(W, D, H, rng)
        est += e
        det += d
        e, d = azotea(-W / 2 + 0.6, W / 2 - 0.6, 6.0, D - 0.4, H, rng, 0, verde=0.0)
    else:
        e, d = azotea(-W / 2 + 0.4, W / 2 - 0.4, 0.4, D - 0.4, H, rng, pisos)
    est += e
    det += d
    o1 = obj(est, bisel=0.05, seg=1)
    o2 = obj(det)
    edif([o1, o2], nombre)
    DATOS[nombre].update({"ancho": W, "fondo": D, "alto": H, "tipo": "medio"})
    base = [P(bm_box(W, 0.6, H, 0, 0.3, 0), fachada, 0, H), P(bm_box(W - 0.04, D - 0.6, H, 0, 0.6 + (D - 0.6) / 2, 0), "medianera", 0, H),
            P(bm_box(W - 0.4, D - 0.4, 0.06, 0, D / 2, H), "azotea")]
    base = base + [P(bm_box(W, 0.25, PRETIL, 0, 0.125, H), fachada, 0, H + PRETIL),
                       P(bm_box(W, 0.25, PRETIL, 0, D - 0.125, H), "medianera")] + \
        [P(bm_box(0.25, D - 0.5, PRETIL, s * (W / 2 - 0.125), D / 2, H), "medianera") for s in (-1, 1)]
    if con_mansarda:
        y0, y1, alto, entra = 0.7, D - 0.6, 3.2, 1.4
        base.append(P(bm_perfil_x([(y0, H), (y1, H), (y1 - entra, H + alto), (y0 + entra, H + alto)], -W / 2 + 0.3, W / 2 - 0.3), "pizarra"))
    else:
        base += _techo_lejos(0, D - 2.2, H, pisos)
    lejos(nombre, [F], base, H, pisos, estilo, toldo_col)


def mansarda(W, D, H, rng):
    """Techo francés de pizarra con buhardillas (lucarnas) al frente."""
    est, det = [], []
    y0, y1, alto, entra = 0.7, D - 0.6, 3.2, 1.4
    perfil = [(y0, H), (y1, H), (y1 - entra, H + alto), (y0 + entra, H + alto)]
    est.append(P(bm_perfil_x(perfil, -W / 2 + 0.3, W / 2 - 0.3), "pizarra"))
    col_convexo([(x, y, z) for x in (-W / 2 + 0.3, W / 2 - 0.3) for (y, z) in perfil])
    est.append(P(bm_box(W - 0.6 - 0.2, y1 - y0 - 2 * entra + 0.1, 0.12, 0, (y0 + y1) / 2, H + alto), "piedra_osc"))
    bays = max(1, int(round(W / 2.8)))
    bw = W / bays
    zb = H + 0.55
    yd = y0 + entra * (0.55 / alto) - 0.05     # frente de la buhardilla, apenas afuera del faldón
    for i in range(bays):
        x = -W / 2 + bw * (i + 0.5)
        est.append(P(bm_box(1.2, 1.3, 1.5, x, yd + 0.65, zb), "piedra"))
        det.append(P(bm_box(0.75, 0.06, 1.05, x, yd - 0.02, zb + 0.2), "vidrio"))
        det.append(P(bm_box(0.06, 0.08, 1.05, x, yd - 0.03, zb + 0.2), "marco"))
        est.append(P(bm_perfil_y([(x - 0.72, zb + 1.5), (x + 0.72, zb + 1.5), (x, zb + 2.05)], yd - 0.1, yd + 1.4), "pizarra"))
    return est, det


def esquina(nombre, C, ch, pisos, estilo, fachada, seed, pb="cafe", toldo_col=None, rayas=0, cupula=None,
            opciones=None):
    """Edificio de esquina con ochava. Ocupa x∈[0,C], y∈[0,C]; fachadas en y=0 (hacia -Y),
    x=0 (hacia -X) y la ochava en diagonal entre (0,ch) y (ch,0)."""
    empezar()
    rng = random.Random(seed)
    H = PB + pisos * PISO
    planta = [(ch, 0), (C, 0), (C, C), (0, C), (0, ch)]
    est = [P(bm_prisma(planta, 0, H), fachada, 0, H)]
    col_prisma(planta, 0, H)
    det = []
    caras = [Frente(((ch + C) / 2, 0), (0, -1), C - ch),
             Frente((0, (ch + C) / 2), (-1, 0), C - ch),
             Frente((ch / 2, ch / 2), (-1, -1), ch * math.sqrt(2))]
    for i, F in enumerate(caras):
        if i < 2:
            e, d = planta_baja(F, "local" if pb == "cafe" else pb, fachada, rng, toldo_col, rayas)
        else:
            e, d = [], [P(F.caja(0, 0, F.w - 0.6, 3.0, 0.06), "sombra"), P(F.caja(0, 0.05, 1.6, 2.6, 0.1), "vidrio_osc"),
                        P(F.caja(0, 2.65, 2.2, 0.35, 0.12), "piedra"), P(F.caja(0, 0, 0.08, 2.65, 0.14), "madera")]
            e.append(P(F.caja(0, PB - 0.12, F.w + 0.08, 0.3, 0.2), "piedra"))
        est += e
        det += d
        e, d = pisos_fachada(F, pisos, estilo if (i < 2 or estilo != "departamentos") else "clasico", fachada, rng, PB,
                             opciones)
        est += e
        det += d
        e, d = remate(F, H, estilo, fachada, rng)
        est += e
        det += d
    det.append(P(bm_prisma(planta, H, H + 0.06), "azotea"))
    e0 = 0.25
    # pretil por todo el borde
    for i, (a, b) in enumerate(zip(planta, planta[1:] + planta[:1])):
        a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
        d_ = b - a
        L = d_.length
        t = d_.normalized()
        n = Vector((t.y, -t.x, 0))   # la planta va en sentido antihorario: la normal de afuera es la derecha
        F = Frente((a + b) / 2, n, L)
        frente = i in (0, 3, 4)       # frente, costado y ochava; los otros dos lados son medianeras
        est.append(P(F.caja(0, H, L, PRETIL, e0, -e0), fachada if frente else "medianera", 0, H + PRETIL))
        F.col(0, H, L, PRETIL, e0, -e0)
    if cupula:
        cx = cy = ch / 2 + 2.2
        r = 2.3
        est.append(P(bm_cyl((cx, cy, H), (cx, cy, H + 2.4), r, r, 16), fachada))
        for k in range(8):
            a = 2 * math.pi * (k + 0.5) / 8
            det.append(P(bm_box(0.5, 0.5, 1.3, cx + (r + 0.05) * math.cos(a), cy + (r + 0.05) * math.sin(a), H + 0.6), "vidrio"))
        est.append(P(bm_cyl((cx, cy, H + 2.4), (cx, cy, H + 2.65), r + 0.25, r + 0.25, 16), "piedra"))
        perfil = [(r + 0.1, H + 2.65)] + [(r * math.cos(math.radians(a)) + 0.1, H + 2.65 + r * 1.15 * math.sin(math.radians(a)))
                                           for a in (20, 40, 60, 75)] + [(0.35, H + 2.65 + r * 1.12), (0, H + 2.65 + r * 1.13)]
        est.append(P(bm_torno(perfil, 16, cx, cy), cupula, H + 2.4, H + 2.65 + r * 1.15))
        zl = H + 2.65 + r * 1.1
        est.append(P(bm_cyl((cx, cy, zl), (cx, cy, zl + 0.9), 0.4, 0.35, 8), "piedra"))
        det.append(P(bm_cyl((cx, cy, zl + 0.9), (cx, cy, zl + 2.0), 0.08, 0.01, 6), "metal"))
        col_esfera((cx, cy, H + 2.0), r + 0.2)
    e, d = azotea(C / 2 - 1.0, C - 0.6, C / 2 - 1.0, C - 0.4, H, rng, pisos)
    est += e
    det += d
    o1 = obj(est, bisel=0.05, seg=1)
    o2 = obj(det)
    edif([o1, o2], nombre)
    DATOS[nombre].update({"ancho": C, "fondo": C, "alto": H, "tipo": "esquina", "ochava": ch})
    base = [P(bm_prisma(planta, 0, H), fachada, 0, H), P(bm_prisma(planta, H, H + 0.06), "azotea")]
    for i, (a, b) in enumerate(zip(planta, planta[1:] + planta[:1])):
        a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
        t = (b - a).normalized()
        F = Frente((a + b) / 2, Vector((t.y, -t.x, 0)), (b - a).length)
        base.append(P(F.caja(0, H, F.w, PRETIL, 0.25, -0.25), fachada if i in (0, 3, 4) else "medianera", 0, H + PRETIL))
    base += _techo_lejos(C - 4.0, C - 4.0, H, pisos)
    if cupula:
        cx = cy = ch / 2 + 2.2
        base.append(P(bm_cyl((cx, cy, H), (cx, cy, H + 2.65), 2.3, 2.3, 10), fachada))
        base.append(P(bm_torno([(2.4, H + 2.65), (1.9, H + 4.2), (0.9, H + 5.1), (0, H + 5.3)], 10, cx, cy), cupula))
    lejos(nombre, caras[:2], base, H, pisos, estilo, toldo_col)


def casa_barrio(nombre, W, D, pisos, fachada, seed, techo="chapa", ladrillo_arriba=False):
    """Casa del barrio enemigo: paredes gastadas con grafitis, rejas, portón de chapa y techo de chapa
    (o losa con el piso de arriba en ladrillo a la vista y hierros que asoman)."""
    empezar()
    rng = random.Random(seed)
    alto_p = 3.0
    H = 0.3 + pisos * alto_p
    F = Frente((0, 0), (0, -1), W)
    est = [P(bm_box(W, D, H, 0, D / 2, 0), fachada, 0, H)]
    col_caja((0, D / 2, H / 2), (W, D, H))
    det = [P(F.caja(0, 0, W, 0.5, 0.05), "piedra_osc")]
    # portón de chapa y puerta
    g = min(2.8, W * 0.38)
    det.append(P(F.caja(-W / 2 + 0.5 + g / 2, 0, g, 2.4, 0.08), rng.choice(("chapa", "oxido", "kiosco"))))
    for j in range(8):
        det.append(P(F.caja(-W / 2 + 0.5 + g / 2, 0.1 + j * 0.29, g, 0.03, 0.1), "oxido"))
    det.append(P(F.caja(W / 2 - 1.3, 0, 0.95, 2.2, 0.08), rng.choice(("madera", "hierro", "plastico_azul"))))
    for p in range(pisos):
        zv = 0.3 + p * alto_p + 1.0
        u = (W / 2 - 1.3) if p == 0 else rng.uniform(-W / 4, W / 4)
        if p == 0:
            u = 0.8 if W > 7 else 0.2
        det += ventana(F, u, zv, 1.1, 1.2, rng, 0.6, marco="persiana")
        det += baranda(F, u, zv, 1.2, 0.16, alto=1.25, sep=0.13)
    # grafitis: manchas de color en la parte de abajo
    for _ in range(rng.randint(2, 4)):
        w = rng.uniform(0.8, 2.4)
        h = rng.uniform(0.4, 1.2)
        u = rng.uniform(-W / 2 + w / 2 + 0.2, W / 2 - w / 2 - 0.2)
        z = rng.uniform(0.4, 1.6)
        det.append(P(F.caja(u, z, w, h, 0.03, 0.02 + rng.uniform(0, 0.01)), rng.choice(("grafiti_rosa", "grafiti_cian", "grafiti_lima"))))
        if rng.random() < 0.6:
            det.append(P(F.caja(u + rng.uniform(-0.3, 0.3), z + rng.uniform(0.1, 0.3), w * 0.6, h * 0.35, 0.03, 0.035),
                         rng.choice(("blanco", "hierro", "plastico_amarillo"))))
    # cables y caja de luz
    det.append(P(F.caja(-W / 2 + 0.3, 1.4, 0.4, 0.5, 0.15), "persiana"))
    if techo == "chapa":
        # chapa a un agua, con canaletas (rayas) y manchas de óxido
        ang = math.radians(8)
        L = (D + 0.6) / math.cos(ang)
        R = Matrix.Translation((0, -0.4, H + 0.15)) @ Matrix.Rotation(ang, 4, "X")
        n = int(W / 0.35)
        for i in range(n):
            x = -W / 2 - 0.15 + (i + 0.5) * (W + 0.3) / n
            c = "oxido" if rng.random() < 0.18 else "chapa"
            b = bm_box((W + 0.3) / n * 0.92, L, 0.06 if i % 2 else 0.1, x, L / 2, 0)
            det.append(P(transformar(b, R), c))
        col_caja(R @ Vector((0, L / 2, 0.05)), (W + 0.3, L, 0.1), R.to_3x3())
        est.append(P(bm_box(W, 0.2, 0.3 + D * math.tan(ang), 0, D - 0.1, H), fachada))
    else:
        est.append(P(bm_box(W, 0.2, 0.7, 0, 0.1, H), fachada))
        col_caja((0, 0.1, H + 0.35), (W, 0.2, 0.7))
        det.append(P(bm_box(W - 0.2, D - 0.2, 0.05, 0, D / 2, H), "piedra_osc"))
        if ladrillo_arriba:
            w2 = W * 0.6
            est.append(P(bm_box(w2, D * 0.5, 2.6, W / 2 - w2 / 2 - 0.1, D * 0.62, H), "ladrillo"))
            col_caja((W / 2 - w2 / 2 - 0.1, D * 0.62, H + 1.3), (w2, D * 0.5, 2.6))
            for k in range(4):
                x = W / 2 - 0.3 - k * (w2 - 0.4) / 3
                det.append(P(bm_cyl((x, D * 0.37 + 0.1, H + 2.6), (x, D * 0.37 + 0.1, H + 3.4), 0.025, 0.025, 4), "oxido"))
        det += tanque(rng.uniform(-W / 2 + 1.2, -W / 2 + 2.2), D - 2.0, H)
        if rng.random() < 0.6:
            det += tendedero(0, D * 0.25, H, min(W - 1.5, 3.2), rng)
    o1 = obj(est, bisel=0.04, seg=1)
    o2 = obj(det)
    edif([o1, o2], nombre)
    DATOS[nombre].update({"ancho": W, "fondo": D, "alto": H, "tipo": "barrio"})
    base = [P(bm_box(W, D, H, 0, D / 2, 0), fachada, 0, H)]
    if techo == "chapa":
        ang = math.radians(8)
        L = (D + 0.6) / math.cos(ang)
        R = Matrix.Translation((0, -0.4, H + 0.15)) @ Matrix.Rotation(ang, 4, "X")
        base.append(P(transformar(bm_box(W + 0.3, L, 0.1, 0, L / 2, 0), R), "chapa"))
        base.append(P(bm_box(W, 0.2, 0.3 + D * math.tan(ang), 0, D - 0.1, H), fachada))
    else:
        base += [P(bm_box(W - 0.2, D - 0.2, 0.05, 0, D / 2, H), "piedra_osc"), P(bm_box(W, 0.2, 0.7, 0, 0.1, H), fachada)]
        if ladrillo_arriba:
            w2 = W * 0.6
            base.append(P(bm_box(w2, D * 0.5, 2.6, W / 2 - w2 / 2 - 0.1, D * 0.62, H), "ladrillo"))
    lejos(nombre, [F], base, H, pisos, "barrio")


def hacer_edificios():
    E = edificio
    # 6 m: PH angostos
    E("ph_6_a", 6, 16, 2, "clasico", "fachada_rosa", 101, pb="entrada", techo="plano")
    E("ph_6_b", 6, 16, 3, "ladrillo", "ladrillo", 102, pb="local", toldo_col="toldo_verde")
    E("ph_6_c", 6, 16, 2, "clasico", "fachada_celeste", 103, pb="local", toldo_col="toldo_amarillo", rayas=4)
    # 8 m
    E("casa_8_a", 8, 16, 2, "clasico", "fachada_crema", 111, pb="local", toldo_col="toldo_rojo", rayas=6)
    E("dep_8_a", 8, 16, 7, "departamentos", "fachada_gris", 112, pb="entrada", opciones={"maciza": True})
    E("clas_8_b", 8, 16, 4, "clasico", "fachada_celeste", 113, pb="local", toldo_col="toldo_azul", techo="mansarda")
    E("ladr_8_a", 8, 16, 3, "ladrillo", "ladrillo", 114, pb="local", toldo_col="toldo_amarillo")
    # 10 m
    E("dep_10_a", 10, 16, 8, "departamentos", "fachada_crema", 121, pb="local", toldo_col="toldo_verde")
    E("clas_10_a", 10, 16, 5, "clasico", "fachada_beige", 122, pb="entrada", techo="mansarda")
    E("mod_10_a", 10, 16, 9, "moderno", "fachada_gris", 123, pb="local", cartel_col="hierro")
    E("dep_10_b", 10, 16, 6, "departamentos", "fachada_terracota", 124, pb="garaje", opciones={"maciza": False})
    E("clas_10_c", 10, 16, 3, "clasico", "fachada_amarilla", 125, pb="local", toldo_col="toldo_rojo", rayas=8)
    # 12 m
    E("dep_12_a", 12, 16, 9, "departamentos", "fachada_beige", 131, pb="local", toldo_col="toldo_naranja",
      opciones={"maciza": True, "pared_balcon": "blanco"})
    E("clas_12_a", 12, 16, 4, "clasico", "fachada_amarilla", 132, pb="local", toldo_col="toldo_rojo", rayas=8)
    E("mod_12_a", 12, 16, 10, "moderno", "fachada_beige", 133, pb="local", cartel_col="kiosco", opciones={"banda": "marco"})
    E("ladr_12_a", 12, 16, 5, "ladrillo", "ladrillo", 134, pb="entrada")
    # 14 m
    E("mod_14_a", 14, 16, 10, "moderno", "fachada_gris", 141, pb="local", cartel_col="toldo_azul")
    E("clas_14_a", 14, 16, 5, "clasico", "fachada_lila", 142, pb="local", toldo_col="toldo_verde", rayas=10,
      techo="mansarda")
    E("dep_14_a", 14, 16, 8, "departamentos", "fachada_verde", 143, pb="local", toldo_col="toldo_amarillo",
      opciones={"maciza": False})
    # esquinas con ochava
    esquina("esq_cupula_a", 16, 4, 5, "clasico", "fachada_beige", 201, toldo_col="toldo_verde", cupula="cupula")
    esquina("esq_cupula_b", 16, 4, 4, "clasico", "fachada_rosa", 202, toldo_col="toldo_rojo", rayas=6, cupula="pizarra")
    esquina("esq_dep_a", 16, 4, 8, "departamentos", "fachada_crema", 203, pb="local", toldo_col="toldo_azul")
    esquina("esq_mod_a", 16, 4, 10, "moderno", "fachada_gris", 204, pb="local")
    esquina("esq_ladr_a", 16, 4, 3, "ladrillo", "ladrillo", 205, pb="local", toldo_col="toldo_amarillo", rayas=6)
    # barrio enemigo
    casa_barrio("barrio_6_a", 6, 12, 1, "fachada_verde", 301)
    casa_barrio("barrio_8_a", 8, 12, 1, "fachada_celeste", 302, techo="losa", ladrillo_arriba=True)
    casa_barrio("barrio_8_b", 8, 12, 2, "fachada_rosa", 303, techo="chapa")
    casa_barrio("barrio_10_a", 10, 12, 1, "fachada_amarilla", 304, techo="losa", ladrillo_arriba=True)
    casa_barrio("barrio_10_b", 10, 12, 2, "fachada_gris", 305, techo="chapa")
    casa_barrio("barrio_12_a", 12, 12, 1, "fachada_lila", 306, techo="losa")
    casa_barrio("barrio_14_a", 14, 12, 1, "fachada_terracota", 307, techo="chapa")


# ================================================================= PROPS URBANOS


def hacer_mobiliario():
    # Farola de calle: poste alto con brazo que sale hacia -Y (hacia la calle)
    empezar()
    m = [bm_cyl((0, 0, 0), (0, 0, 0.5), 0.17, 0.13, 8), bm_cyl((0, 0, 0.5), (0, 0, 6.6), 0.09, 0.06, 8)]
    # Brazo: sale vertical del poste y termina horizontal sobre la calle
    pts = [(0, -1.6 * (1 - math.cos(math.radians(a))), 6.5 + 0.55 * math.sin(math.radians(a))) for a in range(0, 91, 15)]
    for a, b in zip(pts, pts[1:]):
        m.append(bm_cyl(a, b, 0.05, 0.05, 6))
    xe, ye, ze = pts[-1]
    m.append(bm_box(0.42, 0.75, 0.16, 0, ye - 0.3, ze - 0.06))
    luz = [bm_box(0.32, 0.6, 0.04, 0, ye - 0.3, ze - 0.1)]
    col_caja((0, 0, 3.3), (0.2, 0.2, 6.6))
    pieza([obj([P(b, "persiana") for b in m]), obj([P(b, "luz") for b in luz])], "farola")

    # Cazuela (cantero del árbol de vereda)
    empezar()
    borde = [bm_box(1.3, 0.12, 0.1, 0, -0.59, 0), bm_box(1.3, 0.12, 0.1, 0, 0.59, 0),
             bm_box(0.12, 1.06, 0.1, -0.59, 0, 0), bm_box(0.12, 1.06, 0.1, 0.59, 0, 0)]
    pieza([obj([P(b, "cordon") for b in borde], bisel=0.015), obj([P(bm_box(1.06, 1.06, 0.06, 0, 0, 0), "tierra")])],
          "cazuela", sombra=False, rango=120)

    # Árboles de vereda (plátanos/fresnos facetados, más grandes que los del parque)
    def arbol_calle(nombre, seed, alto, copas, color="hoja"):
        empezar()
        rng = random.Random(seed)
        tr = [bm_cyl((0, 0, 0), (0, 0, alto), 0.2, 0.14, 7)]
        tr.append(bm_cyl((0, 0, alto * 0.75), (0.7, 0.2, alto + 0.6), 0.09, 0.06, 6))
        tr.append(bm_cyl((0, 0, alto * 0.7), (-0.6, -0.3, alto + 0.4), 0.09, 0.06, 6))
        hojas = [bm_blob((x, y, alto + z), r, (1, 1, 0.85), 2, 0.08, rng) for x, y, z, r in copas]
        cz = alto + sum(c[2] for c in copas) / len(copas)
        rmax = max(math.hypot(c[0], c[1]) + c[3] for c in copas)
        col_esfera((0, 0, cz), rmax * 0.75)
        col_caja((0, 0, alto / 2), (0.36, 0.36, alto))
        pieza([obj([P(b, "tronco") for b in tr]), obj([P(b, color) for b in hojas])], nombre, rango=170)

    arbol_calle("arbol_calle_A", 21, 3.4, [(0, 0, 1.1, 1.4), (1.1, 0.3, 0.7, 1.0), (-1.0, -0.4, 0.8, 1.0), (0.2, 0.9, 0.9, 0.95),
                                           (0.3, -1.0, 0.6, 0.9), (-0.2, 0.2, 1.9, 0.9)])
    arbol_calle("arbol_calle_B", 22, 3.0, [(0, 0, 1.0, 1.2), (0.9, 0.0, 0.6, 0.9), (-0.8, 0.3, 0.7, 0.85), (0.1, -0.8, 0.8, 0.8),
                                           (0, 0.1, 1.8, 0.75)], "hoja_osc")
    arbol_calle("arbol_calle_C", 23, 3.6, [(0, 0, 1.2, 1.5), (1.2, -0.2, 0.9, 1.0), (-1.1, 0.4, 0.8, 1.05), (0.4, 1.0, 0.7, 0.9),
                                           (-0.3, -1.0, 0.9, 0.9), (0.2, 0.0, 2.2, 0.85)], "hoja")
    arbol_calle("jacaranda_calle", 24, 3.2, [(0, 0, 1.0, 1.4), (1.2, 0.4, 0.6, 1.0), (-1.1, 0.3, 0.7, 1.05), (0.3, -1.1, 0.6, 0.95),
                                             (-0.5, -0.8, 0.9, 0.8), (0.1, 0.4, 1.6, 0.85)], "jacaranda")

    # Cartel de calle porteño: poste negro con dos placas (los nombres los pone Godot)
    empezar()
    m = [bm_cyl((0, 0, 0), (0, 0, 3.15), 0.045, 0.04, 8), bm_blob((0, 0, 3.17), 0.06, sub=1)]
    # Las placas salen hacia un costado del poste (centradas, el poste tapaba el medio del nombre)
    placas = [bm_box(1.0, 0.04, 0.24, 0.55, 0, 2.78), bm_box(0.04, 1.0, 0.24, 0, -0.55, 2.5)]
    marco = [bm_box(1.04, 0.03, 0.03, 0.55, 0, 3.0), bm_box(0.03, 1.04, 0.03, 0, -0.55, 2.72)]
    pieza([obj([P(b, "hierro") for b in m + placas]), obj([P(b, "blanco") for b in marco])], "cartel_calle", rango=120)
    c = DATOS["cartel_calle"]["col"]
    for p, n in (((0.55, -0.025, 2.9), (0, -1, 0)), ((0.55, 0.025, 2.9), (0, 1, 0)), ((-0.025, -0.55, 2.62), (-1, 0, 0)),
                 ((0.025, -0.55, 2.62), (1, 0, 0))):
        c.carteles.append((Vector(p), Vector(n), 0.92, 0.2, "calle"))

    # Contenedor de basura (verde, como los de la ciudad) y gris de reciclables
    for nombre, color in (("contenedor", "contenedor"), ("contenedor_gris", "persiana")):
        empezar()
        cuerpo = [bm_box(1.7, 1.0, 1.05, 0, 0, 0.18)]
        tapa = bm_perfil_x([(-0.52, 1.23), (0.52, 1.23), (0.4, 1.38), (-0.4, 1.38)], -0.86, 0.86)
        ruedas = [bm_cyl((x, y - 0.08, 0.09), (x, y + 0.08, 0.09), 0.09, 0.09, 8) for x in (-0.65, 0.65) for y in (-0.35, 0.35)]
        pedal = [bm_box(0.3, 0.12, 0.05, 0, -0.56, 0.12)]
        pieza([obj([P(b, color) for b in cuerpo] + [P(tapa, color)], bisel=0.04),
               obj([P(b, "hierro") for b in ruedas + pedal])], nombre, rango=140)
        DATOS[nombre]["col"].cajas.append((Vector((0, 0, 0.69)), Vector((1.7, 1.0, 1.38)), Matrix.Identity(3)))

    # Cesto papelero
    empezar()
    pieza([obj([P(bm_cyl((0, 0, 0), (0, 0, 0.95), 0.05, 0.05, 6), "hierro")]),
           obj([P(bm_torno([(0.2, 0.45), (0.24, 0.95), (0.21, 0.95), (0.17, 0.5), (0, 0.5)], 10), "persiana"),
                P(bm_anillo(0.245, 0.2, 0.82, 0.9, 10), "naranja")])], "cesto", sombra=False, rango=90)

    # Pilote / bolardo
    empezar()
    pieza([obj([P(bm_torno([(0.13, 0), (0.13, 0.7), (0.1, 0.78), (0, 0.8)], 8), "piedra")], bisel=0.02),
           obj([P(bm_anillo(0.135, 0.12, 0.55, 0.62, 8), "plastico_amarillo")])], "pilote", sombra=False, rango=90)

    # Buzón rojo de los de antes
    empezar()
    cuerpo = bm_torno([(0.28, 0.25), (0.28, 1.25), (0.3, 1.28), (0.25, 1.42), (0.08, 1.5), (0, 1.52)], 12)
    pieza([obj([P(bm_cyl((0, 0, 0), (0, 0, 0.25), 0.33, 0.3, 12), "piedra_osc"), P(cuerpo, "buzon")], bisel=0.02),
           obj([P(bm_box(0.3, 0.06, 0.05, 0, -0.27, 1.1), "hierro"), P(bm_box(0.25, 0.02, 0.18, 0, -0.29, 0.75), "blanco")])],
          "buzon", rango=120)
    DATOS["buzon"]["col"].cajas.append((Vector((0, 0, 0.75)), Vector((0.6, 0.6, 1.5)), Matrix.Identity(3)))

    # Kiosco de diarios (puesto de revistas verde)
    empezar()
    rng = random.Random(31)
    est = [P(bm_box(2.4, 1.5, 2.2, 0, 0, 0), "kiosco"), P(bm_box(2.7, 1.9, 0.14, 0, -0.1, 2.2), "kiosco"),
           P(bm_box(2.5, 1.6, 0.25, 0, 0, 2.34), "blanco")]
    det = [P(bm_box(2.2, 0.05, 1.6, 0, -0.76, 0.5), "sombra")]
    for fila in range(3):
        x = -1.0
        while x < 1.0:
            w = rng.uniform(0.18, 0.3)
            det.append(P(bm_box(w, 0.04, 0.32, x + w / 2, -0.8 - fila * 0.02, 0.6 + fila * 0.48),
                         rng.choice(("toldo_rojo", "toldo_azul", "plastico_amarillo", "blanco", "flor_rosa", "plastico_verde"))))
            x += w + 0.05
    det += [P(transformar(bm_box(2.6, 0.9, 0.05, 0, -0.45, 0), Matrix.Translation((0, -0.75, 2.15)) @ Matrix.Rotation(0.3, 4, "X")),
              "toldo_amarillo")]
    pieza([obj(est, bisel=0.04), obj(det)], "kiosco_diarios")
    c = DATOS["kiosco_diarios"]["col"]
    c.cajas.append((Vector((0, 0, 1.25)), Vector((2.6, 1.6, 2.5)), Matrix.Identity(3)))
    c.carteles.append((Vector((0, -0.96, 2.34 + 0.13)), Vector((0, -1, 0)), 2.2, 0.2, "kiosco"))

    # Parada de colectivo (refugio con techo, vidrio, banco y cartel)
    empezar()
    est = [P(bm_box(3.6, 1.6, 0.12, 0, 0, 2.55), "persiana"), P(bm_box(3.4, 0.08, 2.0, 0, 0.7, 0.45), "vidrio")]
    for x in (-1.7, 1.7):
        est.append(P(bm_box(0.1, 0.1, 2.55, x, 0.7, 0), "hierro"))
    est.append(P(bm_box(2.4, 0.4, 0.06, 0, 0.45, 0.45), "madera"))
    for x in (-1.0, 1.0):
        est.append(P(bm_box(0.06, 0.3, 0.45, x, 0.45, 0), "hierro"))
    est.append(P(bm_cyl((-2.2, -0.4, 0), (-2.2, -0.4, 2.9), 0.04, 0.04, 6), "hierro"))
    est.append(P(bm_box(0.06, 0.6, 0.6, -2.2, -0.4, 2.4), "toldo_azul"))
    est.append(P(bm_box(0.065, 0.5, 0.18, -2.2, -0.4, 2.47), "plastico_amarillo"))
    pieza([obj(est)], "parada_colectivo")
    c = DATOS["parada_colectivo"]["col"]
    c.cajas.append((Vector((0, 0, 2.61)), Vector((3.6, 1.6, 0.12)), Matrix.Identity(3)))
    c.cajas.append((Vector((0, 0.7, 1.45)), Vector((3.4, 0.1, 2.1)), Matrix.Identity(3)))

    # Bicicletas
    for nombre, color in (("bici_roja", "plastico_rojo"), ("bici_azul", "plastico_azul"), ("bici_verde", "plastico_verde")):
        empezar()
        R90 = Matrix.Rotation(math.radians(90), 4, "X")
        ruedas = []
        for x in (-0.55, 0.55):
            ruedas.append(transformar(bm_anillo(0.34, 0.3, -0.025, 0.025, 14), Matrix.Translation((x, 0, 0.34)) @ R90))
            ruedas.append(transformar(bm_cyl((0, 0, -0.04), (0, 0, 0.04), 0.05, 0.05, 6), Matrix.Translation((x, 0, 0.34)) @ R90))
        cuadro = [bm_cyl((-0.55, 0, 0.34), (-0.05, 0, 0.36), 0.025), bm_cyl((-0.05, 0, 0.36), (0.35, 0, 0.75), 0.025),
                  bm_cyl((-0.55, 0, 0.34), (-0.15, 0, 0.75), 0.025), bm_cyl((-0.15, 0, 0.75), (0.35, 0, 0.75), 0.025),
                  bm_cyl((-0.05, 0, 0.36), (-0.2, 0, 0.82), 0.025), bm_cyl((0.55, 0, 0.34), (0.38, 0, 0.92), 0.025)]
        otros = [bm_box(0.25, 0.1, 0.05, -0.22, 0, 0.84), bm_cyl((0.38, -0.25, 0.95), (0.38, 0.25, 0.95), 0.02)]
        pieza([obj([P(b, "hierro") for b in ruedas + otros]), obj([P(b, color) for b in cuadro])], nombre, sombra=False, rango=80)

    # Macetón de hormigón hexagonal con un arbusto (como en las veredas y pasajes)
    for nombre, seed in (("maceton", 41), ("maceton_flores", 42)):
        empezar()
        rng = random.Random(seed)
        base = bm_torno([(0.55, 0), (0.6, 0.65), (0.5, 0.65), (0.5, 0.55), (0, 0.55)], 6)
        hojas = [bm_blob((0, 0, 0.95), 0.5, (1, 1, 0.85), 2, 0.08, rng), bm_blob((0.25, 0.1, 1.2), 0.32, (1, 1, 1), 2, 0.08, rng)]
        partes = [obj([P(base, "blanco")], bisel=0.03), obj([P(b, "hoja_osc") for b in hojas])]
        if "flores" in nombre:
            fl = [bm_blob((0.45 * math.cos(a), 0.45 * math.sin(a), 1.0 + 0.2 * math.sin(3 * a)), 0.07, sub=0) for a in
                  [rng.uniform(0, 6.28) for _ in range(12)]]
            partes.append(obj([P(b, rng.choice(("flor_rosa", "flor_amarilla"))) for b in fl]))
        pieza(partes, nombre, rango=110)
        DATOS[nombre]["col"].cajas.append((Vector((0, 0, 0.6)), Vector((1.1, 1.1, 1.2)), Matrix.Identity(3)))

    # Cono de tránsito
    empezar()
    pieza([obj([P(bm_box(0.42, 0.42, 0.05, 0, 0, 0), "naranja"), P(bm_cyl((0, 0, 0.05), (0, 0, 0.7), 0.17, 0.03, 8), "naranja"),
                P(bm_anillo(0.13, 0.08, 0.3, 0.42, 8), "blanco")])], "cono", sombra=False, rango=70)

    # Guirnalda de lamparitas (cruza el pasaje: 6 m entre ganchos)
    empezar()
    pts = [(x, 0, 4.6 - 0.55 * (1 - (x / 3.0) ** 2)) for x in [-3 + 0.5 * i for i in range(13)]]
    cable = [bm_cyl(a, b, 0.012, 0.012, 4) for a, b in zip(pts, pts[1:])]
    focos = [bm_blob((x, 0, z - 0.1), 0.08, (1, 1, 1.25), 1) for x, _, z in pts[1:-1]]
    pieza([obj([P(b, "hierro") for b in cable]), obj([P(b, "luz") for b in focos])], "guirnalda", sombra=False, rango=90)

    # Tendedero suelto (para patios y terrazas)
    empezar()
    pieza([obj(tendedero(0, 0, 0, 3.0, random.Random(5)))], "tendedero", sombra=False, rango=100)

    # Tanque de agua suelto
    empezar()
    pieza([obj(tanque(0, 0, 0))], "tanque")

    # Bebedero de plaza
    empezar()
    pieza([obj([P(bm_box(0.5, 0.5, 0.9, 0, 0, 0), "piedra"), P(bm_box(0.7, 0.6, 0.12, 0, 0, 0.9), "piedra")], bisel=0.03),
           obj([P(bm_cyl((0, -0.1, 1.02), (0, -0.1, 1.15), 0.04, 0.03, 6), "metal"), P(bm_box(0.45, 0.35, 0.03, 0, 0, 1.025), "agua")])],
          "bebedero", rango=100)
    DATOS["bebedero"]["col"].cajas.append((Vector((0, 0, 0.51)), Vector((0.7, 0.6, 1.02)), Matrix.Identity(3)))

    # Bolsas de basura
    empezar()
    rng = random.Random(51)
    bolsas = [bm_blob((rng.uniform(-0.5, 0.5), rng.uniform(-0.3, 0.3), 0.28), rng.uniform(0.25, 0.35), (1, 1, 0.9), 2, 0.1, rng)
              for _ in range(5)]
    pieza([obj([P(b, "metal") for b in bolsas])], "bolsas", sombra=False, rango=80)


# ================================================================= PLAZA: juegos, perros, palomas


def hacer_juegos():
    # Hamacas: marco (fijo) y asiento (se anima en Godot girando sobre su origen, el eje de arriba)
    empezar()
    marco = []
    for x in (-1.7, 1.7):
        for s in (-1, 1):
            marco.append(bm_cyl((x, s * 0.9, 0), (x, 0, 2.5), 0.06, 0.05, 8))
    marco.append(bm_cyl((-1.8, 0, 2.5), (1.8, 0, 2.5), 0.07, 0.07, 8))
    pieza([obj([P(b, "plastico_azul") for b in marco[:4]] + [P(b, "plastico_rojo") for b in marco[4:]])], "hamaca_marco")
    c = DATOS["hamaca_marco"]["col"]
    c.cajas.append((Vector((0, 0, 2.5)), Vector((3.6, 0.16, 0.16)), Matrix.Identity(3)))
    empezar()
    cad = [bm_cyl((x, 0, 0), (x, 0, -1.95), 0.012, 0.012, 4) for x in (-0.22, 0.22)]
    pieza([obj([P(b, "metal") for b in cad]), obj([P(bm_box(0.5, 0.22, 0.05, 0, 0, -2.0), "plastico_amarillo")], bisel=0.015)],
          "hamaca_asiento", sombra=False)

    # Tobogán
    empezar()
    est = []
    for x in (-0.55, 0.55):
        for y in (-0.55, 0.55):
            est.append(P(bm_cyl((x, y, 0), (x, y, 2.6), 0.06, 0.06, 8), "plastico_azul"))
    est.append(P(bm_box(1.25, 1.25, 0.1, 0, 0, 1.45), "madera"))
    for s in (-1, 1):
        est.append(P(bm_box(0.06, 1.2, 0.06, s * 0.58, 0, 2.15), "plastico_azul"))
    techo = bm_perfil_x([(-0.75, 2.6), (0.75, 2.6), (0, 3.15)], -0.75, 0.75)
    est.append(P(techo, "plastico_rojo"))
    for k in range(5):
        est.append(P(bm_box(0.6, 0.05, 0.05, 0, 0.75, 0.3 + k * 0.3), "plastico_verde"))
    for s in (-1, 1):
        est.append(P(bm_cyl((s * 0.3, 0.6, 0), (s * 0.3, 0.75, 1.55), 0.035, 0.035, 6), "plastico_verde"))
    ang = math.atan2(1.45, 2.6)
    L = math.hypot(1.45, 2.6)
    R = Matrix.Translation((0, -0.6, 1.5)) @ Matrix.Rotation(ang, 4, "X")
    tob = [transformar(bm_box(0.62, L, 0.06, 0, -L / 2, 0), R)]
    for s in (-1, 1):
        tob.append(transformar(bm_box(0.06, L, 0.2, s * 0.31, -L / 2, 0), R))
    tob.append(bm_box(0.62, 0.5, 0.06, 0, -3.35, 0.05))
    est += [P(b, "plastico_amarillo") for b in tob]
    pieza([obj(est, bisel=0.02)], "tobogan")
    c = DATOS["tobogan"]["col"]
    c.cajas.append((Vector((0, 0, 1.5)), Vector((1.25, 1.25, 0.1)), Matrix.Identity(3)))
    c.cajas.append((R @ Vector((0, -L / 2, 0.03)), Vector((0.62, L, 0.1)), R.to_3x3()))
    c.convexos.append([Vector(p) for p in ((-0.75, -0.75, 2.6), (0.75, -0.75, 2.6), (-0.75, 0.75, 2.6), (0.75, 0.75, 2.6),
                                            (-0.75, 0, 3.15), (0.75, 0, 3.15))])

    # Subibaja: base fija y tabla (gira sobre su origen, el eje)
    empezar()
    pieza([obj([P(bm_box(0.3, 0.5, 0.45, 0, 0, 0), "plastico_rojo"), P(bm_cyl((0, -0.27, 0.5), (0, 0.27, 0.5), 0.06, 0.06, 8), "metal")],
               bisel=0.02)], "subibaja_base")
    empezar()
    tabla = [bm_box(3.4, 0.28, 0.08, 0, 0, 0.0)]
    asas = []
    for s in (-1, 1):
        tabla.append(bm_box(0.4, 0.3, 0.05, s * 1.45, 0, 0.08))
        asas.append(bm_cyl((s * 1.15, 0, 0.08), (s * 1.15, 0, 0.4), 0.025, 0.025, 6))
        asas.append(bm_cyl((s * 1.15, -0.12, 0.4), (s * 1.15, 0.12, 0.4), 0.025, 0.025, 6))
    pieza([obj([P(b, "plastico_amarillo") for b in tabla], bisel=0.02), obj([P(b, "metal") for b in asas])], "subibaja_tabla",
          sombra=True)

    # Arenero
    empezar()
    borde = [bm_box(3.2, 0.25, 0.3, 0, -1.475, 0), bm_box(3.2, 0.25, 0.3, 0, 1.475, 0), bm_box(0.25, 2.7, 0.3, -1.475, 0, 0),
             bm_box(0.25, 2.7, 0.3, 1.475, 0, 0)]
    pieza([obj([P(b, "madera") for b in borde], bisel=0.03), obj([P(bm_box(2.7, 2.7, 0.22, 0, 0, 0), "arena")])], "arenero",
          sombra=False)

    # Calesita: base fija y parte que gira (plataforma, columna, techo a rayas y caballitos)
    empezar()
    pieza([obj([P(bm_torno([(4.2, 0), (4.2, 0.28), (0, 0.28)], 24), "piedra")], bisel=0.03)], "calesita_base", sombra=False)
    DATOS["calesita_base"]["col"].cajas.append((Vector((0, 0, 0.14)), Vector((8.0, 8.0, 0.28)), Matrix.Identity(3)))
    empezar()
    rng = random.Random(61)
    est = [P(bm_torno([(3.8, 0.28), (3.8, 0.45), (0, 0.45)], 24), "madera"),
           P(bm_cyl((0, 0, 0.45), (0, 0, 3.3), 0.55, 0.55, 12), "blanco")]
    det = []
    for k in range(12):
        a = 2 * math.pi * (k + 0.5) / 12
        det.append(P(transformar(bm_box(0.25, 0.04, 2.3, 0, 0, 0), Matrix.Translation((0.56 * math.cos(a), 0.56 * math.sin(a), 0.75)) @
                                 Matrix.Rotation(a + math.pi / 2, 4, "Z")), "vidrio"))
    seg = 16
    for k in range(seg):
        a0, a1 = 2 * math.pi * k / seg, 2 * math.pi * (k + 1) / seg
        bm = bmesh.new()
        v = [bm.verts.new((0, 0, 4.6)), bm.verts.new((4.2 * math.cos(a0), 4.2 * math.sin(a0), 3.4)),
             bm.verts.new((4.2 * math.cos(a1), 4.2 * math.sin(a1), 3.4))]
        w = [bm.verts.new((0, 0, 3.35)), bm.verts.new((4.2 * math.cos(a0), 4.2 * math.sin(a0), 3.3)),
             bm.verts.new((4.2 * math.cos(a1), 4.2 * math.sin(a1), 3.3))]
        bm.faces.new((v[0], v[1], v[2]))
        bm.faces.new((w[0], w[2], w[1]))
        bm.faces.new((v[1], w[1], w[2], v[2]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        est.append(P(bm, "toldo_rojo" if k % 2 == 0 else "blanco", 3.3, 4.6))
    est.append(P(bm_anillo(4.25, 4.1, 2.95, 3.4, 32), "plastico_amarillo"))
    for k in range(16):
        a = 2 * math.pi * k / 16
        det.append(P(bm_blob((4.27 * math.cos(a), 4.27 * math.sin(a), 3.17), 0.07, sub=1), "luz"))
    est.append(P(bm_torno([(0.3, 4.55), (0.3, 4.8), (0.05, 5.2), (0, 5.25)], 8), "plastico_amarillo"))
    colores = ["blanco", "perro_marron", "blanco", "perro_negro", "blanco", "plastico_azul"]
    for k in range(6):
        a = 2 * math.pi * k / 6
        cx, cy = 2.75 * math.cos(a), 2.75 * math.sin(a)
        det.append(P(bm_cyl((cx, cy, 0.45), (cx, cy, 3.3), 0.035, 0.035, 6), "flor_amarilla"))
        T = Matrix.Translation((cx, cy, 1.15 + 0.2 * (k % 2))) @ Matrix.Rotation(a, 4, "Z")
        cab = [bm_blob((0, 0, 0), 0.3, (0.55, 1.25, 0.6), 1), bm_blob((0, -0.42, 0.3), 0.16, (0.6, 1.1, 1.3), 1),
               bm_blob((0, -0.55, 0.42), 0.12, (0.6, 1.2, 0.7), 1)]
        patas = [bm_cyl((sx * 0.1, sy * 0.25, -0.05), (sx * 0.1, sy * 0.35 + sy * 0.15, -0.5), 0.04, 0.03, 5) for sx in (-1, 1) for sy in (-1, 1)]
        det += [P(transformar(b, T), colores[k]) for b in cab + patas]
        det.append(P(transformar(bm_box(0.1, 0.2, 0.25, 0, 0.32, 0.05), T), "toldo_rojo"))
        det.append(P(transformar(bm_box(0.3, 0.35, 0.05, 0, 0.0, 0.18), T), "toldo_rojo"))
    pieza([obj(est, bisel=0.02), obj(det)], "calesita_giro")
    c = DATOS["calesita_giro"]["col"]
    c.convexos.append([Vector((4.2 * math.cos(2 * math.pi * k / 12), 4.2 * math.sin(2 * math.pi * k / 12), z)) for k in range(12)
                       for z in (3.3,)] + [Vector((0, 0, 4.6))])

    # Cerco bajo de colores para el área de juegos (tramo de 3 m: poste sólo en -X, se encadenan)
    empezar()
    est = [P(bm_box(0.12, 0.12, 0.95, -1.5, 0, 0), "madera"), P(bm_blob((-1.5, 0, 1.0), 0.09, sub=1), "plastico_rojo")]
    for z, c in ((0.35, "plastico_azul"), (0.75, "plastico_amarillo")):
        est.append(P(bm_box(3.0, 0.06, 0.14, 0, 0, z), c))
    pieza([obj(est, bisel=0.015)], "cerco_juegos", sombra=False, rango=110)

    # Reja de hierro de plaza (tramo de 3 m con poste en -X) y poste suelto para cerrar
    empezar()
    det = [bm_box(0.1, 0.1, 1.55, -1.5, 0, 0), bm_blob((-1.5, 0, 1.6), 0.08, sub=1), bm_box(3.0, 0.05, 0.06, 0, 0, 1.25),
           bm_box(3.0, 0.05, 0.06, 0, 0, 0.12)]
    for k in range(1, 20):
        x = -1.5 + k * 3.0 / 20
        det.append(bm_box(0.03, 0.03, 1.38, x, 0, 0.05))
        det.append(bm_cyl((x, 0, 1.43), (x, 0, 1.52), 0.03, 0.0, 4))
    pieza([obj([P(b, "hierro") for b in det])], "reja", rango=120)
    DATOS["reja"]["col"].cajas.append((Vector((0, 0, 0.8)), Vector((3.0, 0.12, 1.6)), Matrix.Identity(3)))
    empezar()
    pieza([obj([P(bm_box(0.1, 0.1, 1.55, 0, 0, 0), "hierro"), P(bm_blob((0, 0, 1.6), 0.08, sub=1), "hierro")])], "reja_poste",
          sombra=False)

    # Agility para perros
    empezar()
    est = [P(bm_box(0.12, 0.12, 1.0, x, 0, 0), "plastico_azul") for x in (-0.8, 0.8)]
    for k in range(4):
        est.append(P(bm_box(0.4, 0.06, 0.06, -0.6 + k * 0.4 + 0.2, 0, 0.55), "plastico_rojo" if k % 2 == 0 else "blanco"))
    pieza([obj(est, bisel=0.015)], "agility_salto")
    empezar()
    R90 = Matrix.Rotation(math.radians(90), 4, "Y")
    tubo = transformar(bm_anillo(0.45, 0.38, -1.6, 1.6, 14), Matrix.Translation((0, 0, 0.42)) @ R90)
    pieza([obj([P(tubo, "plastico_amarillo")]), obj([P(bm_box(3.0, 0.06, 0.08, 0, s * 0.42, 0), "plastico_verde") for s in (-1, 1)])],
          "agility_tunel")
    DATOS["agility_tunel"]["col"].cajas.append((Vector((0, 0, 0.42)), Vector((3.2, 0.9, 0.86)), Matrix.Identity(3)))
    empezar()
    rampa = bm_perfil_x([(-1.6, 0), (1.6, 0), (0.15, 1.3), (-0.15, 1.3)], -0.45, 0.45)
    franjas = []
    for s in (-1, 1):
        R = Matrix.Translation((0, s * 1.35, 0.27)) @ Matrix.Rotation(-s * math.atan2(1.3, 1.45), 4, "X")
        franjas.append(transformar(bm_box(0.92, 0.5, 0.04, 0, 0, 0), R))
    pieza([obj([P(rampa, "madera")], bisel=0.02), obj([P(b, "plastico_amarillo") for b in franjas])], "agility_rampa")
    DATOS["agility_rampa"]["col"].convexos.append([Vector((x, y, z)) for x in (-0.45, 0.45) for (y, z) in ((-1.6, 0), (1.6, 0), (0.15, 1.3), (-0.15, 1.3))])

    # Cartel de madera sobre poste (parque de perros, juegos...)
    empezar()
    pieza([obj([P(bm_box(0.1, 0.1, 1.7, x, 0, 0), "madera") for x in (-0.6, 0.6)] + [P(bm_box(1.5, 0.08, 0.6, 0, 0, 1.25), "madera")],
               bisel=0.015)], "cartel_madera")
    DATOS["cartel_madera"]["col"].carteles += [(Vector((0, -0.045, 1.55)), Vector((0, -1, 0)), 1.35, 0.45, "madera"),
                                               (Vector((0, 0.045, 1.55)), Vector((0, 1, 0)), 1.35, 0.45, "madera")]


def animal(nombre, color, color2, especie="perro", pose="parado", escala=1.0, bolt=False):
    """Perro o gato facetado (mira hacia -Y)."""
    empezar()
    s = escala
    cuerpo, detalle, oscuro = [], [], []
    gato = especie == "gato"
    if pose == "echado":
        cuerpo.append(bm_blob((0, 0.05, 0.2), 0.24, (0.85, 1.55, 0.7), 2))
        cuerpo.append(bm_blob((0, -0.42, 0.3), 0.16, (1, 1.1, 1), 2))
        for sx in (-1, 1):
            cuerpo.append(bm_cyl((sx * 0.1, -0.2, 0.06), (sx * 0.1, -0.55, 0.05), 0.05, 0.045, 6))
            cuerpo.append(bm_blob((sx * 0.13, 0.28, 0.12), 0.11, (0.8, 1.4, 0.8), 2))
        cola = bm_cyl((0, 0.42, 0.14), (0.2, 0.62, 0.06), 0.04, 0.02, 5)
        head_c = Vector((0, -0.42, 0.3))
    elif pose == "sentado":
        cuerpo.append(bm_blob((0, 0.12, 0.3), 0.24, (0.85, 1.05, 1.2), 2))
        cuerpo.append(bm_blob((0, -0.08, 0.45), 0.18, (0.9, 1, 1.1), 2))
        for sx in (-1, 1):
            cuerpo.append(bm_cyl((sx * 0.09, -0.12, 0.35), (sx * 0.09, -0.16, 0.0), 0.045, 0.04, 6))
            cuerpo.append(bm_blob((sx * 0.15, 0.2, 0.14), 0.12, (0.8, 1.3, 0.9), 2))
        cola = bm_cyl((0, 0.32, 0.06), (0.25, 0.25, 0.04), 0.04, 0.02, 5)
        head_c = Vector((0, -0.14, 0.7))
    else:
        cuerpo.append(bm_blob((0, 0.05, 0.45), 0.24, (0.8, 1.45, 0.8), 2))
        cuerpo.append(bm_blob((0, -0.2, 0.5), 0.2, (0.9, 1, 0.95), 2))
        for sx in (-1, 1):
            for sy in (-0.22, 0.28):
                cuerpo.append(bm_cyl((sx * 0.11, sy, 0.42), (sx * 0.11, sy, 0.0), 0.05, 0.045, 6))
        cola = bm_cyl((0, 0.36, 0.52), (0, 0.55, 0.78), 0.04, 0.02, 5)
        head_c = Vector((0, -0.42, 0.68))
    cuerpo.append(bm_blob(head_c, 0.16, (1, 1.05, 1), 2))
    cuerpo.append(cola)
    hx, hy, hz = head_c
    if gato:
        detalle.append(bm_box(0.12, 0.08, 0.08, hx, hy - 0.15, hz - 0.04))
        for sx in (-1, 1):
            oscuro.append(bm_cyl((hx + sx * 0.08, hy, hz + 0.1), (hx + sx * 0.1, hy, hz + 0.26), 0.06, 0.0, 4))
    else:
        detalle.append(bm_box(0.13, 0.17, 0.11, hx, hy - 0.16, hz - 0.08))
        for sx in (-1, 1):
            oscuro.append(bm_cyl((hx + sx * 0.1, hy + 0.02, hz + 0.08), (hx + sx * 0.14, hy + 0.04, hz - 0.06), 0.06, 0.03, 4))
    ojos = [bm_box(0.035, 0.03, 0.035, hx + sx * 0.07, hy - 0.13, hz + 0.04) for sx in (-1, 1)]
    ojos.append(bm_box(0.06, 0.04, 0.05, hx, hy - (0.18 if gato else 0.26), hz - (0.02 if gato else 0.04)))
    partes = [obj([P(b, color) for b in cuerpo]), obj([P(b, color2) for b in detalle + oscuro]), obj([P(b, "hierro") for b in ojos])]
    if bolt:
        # Rayo negro en el costado: una placa en zigzag que atraviesa el lomo y asoma por el lado +X
        rayo = [(0.0, 0.42), (0.12, 0.42), (0.05, 0.3), (0.16, 0.3), (-0.06, 0.08), (0.0, 0.24), (-0.1, 0.24)]
        bm = bm_prisma([(y * 1.3 - 0.06, z * 0.35) for y, z in rayo], 0.1, 0.212)
        R = Matrix.Translation((0, 0.0, 0.13)) @ Matrix.Rotation(math.radians(90), 4, "Y") @ Matrix.Rotation(math.radians(90), 4, "Z")
        partes.append(obj([P(transformar(bm, R), "hierro")]))
    for p in partes:
        if p:
            p.scale = (s, s, s)
            _activar([p])
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    pieza(partes, nombre, sombra=True, rango=90)


def hacer_animales():
    animal("perro_marron", "perro_marron", "perro_blanco")
    animal("perro_negro", "perro_negro", "perro_marron", pose="sentado")
    animal("perro_blanco", "perro_blanco", "perro_marron", escala=0.85)
    animal("perro_echado", "perro_marron", "perro_negro", pose="echado", escala=1.1)
    animal("perro_bolt", "perro_blanco", "perro_blanco", pose="echado", escala=1.0, bolt=True)
    animal("gato_naranja", "gato_naranja", "blanco", especie="gato", pose="sentado", escala=0.55)
    animal("gato_negro", "perro_negro", "perro_negro", especie="gato", pose="echado", escala=0.6)
    animal("gato_gris", "persiana", "blanco", especie="gato", pose="sentado", escala=0.55)

    # Cucha de Bolt (el nombre lo pone Godot sobre la puerta), plato y hueso
    empezar()
    # Techo a dos aguas con la cumbrera de adelante hacia atrás (el frontón mira a la puerta)
    est = [P(bm_box(1.2, 1.4, 0.9, 0, 0, 0), "madera"),
           P(bm_perfil_y([(-0.85, 0.85), (0.85, 0.85), (0, 1.45)], -0.78, 0.78), "tejas")]
    det = [P(bm_box(0.55, 0.04, 0.6, 0, -0.71, 0.0), "sombra"), P(bm_box(0.6, 0.05, 0.16, 0, -0.8, 1.0), "blanco")]
    pieza([obj(est, bisel=0.03), obj(det)], "cucha")
    c = DATOS["cucha"]["col"]
    c.cajas.append((Vector((0, 0, 0.45)), Vector((1.2, 1.4, 0.9)), Matrix.Identity(3)))
    c.carteles.append((Vector((0, -0.83, 1.08)), Vector((0, -1, 0)), 0.55, 0.13, "cucha"))
    empezar()
    pieza([obj([P(bm_torno([(0.12, 0), (0.17, 0.08), (0.14, 0.08), (0.1, 0.02), (0, 0.02)], 12), "plastico_rojo")]),
           obj([P(bm_box(0.24, 0.06, 0.05, 0.35, 0.1, 0), "perro_blanco")] +
               [P(bm_blob((0.35 + sx * 0.13, 0.1 + sy * 0.03, 0.03), 0.04, sub=1), "perro_blanco") for sx in (-1, 1) for sy in (-1, 1)])],
          "plato_hueso", sombra=False)

    # Estatua de la paloma (zona de palomas): pedestal de piedra y paloma de bronce verdoso
    empezar()
    est = [P(bm_box(2.0, 2.0, 0.3, 0, 0, 0), "piedra"), P(bm_box(1.5, 1.5, 0.9, 0, 0, 0.3), "piedra"),
           P(bm_box(1.8, 1.8, 0.18, 0, 0, 1.2), "piedra")]
    z = 1.38
    E = 1.7   # la paloma es grande: se ve desde toda la plaza
    S = Matrix.Translation((0, 0, z)) @ Matrix.Scale(E, 4) @ Matrix.Translation((0, 0, -z))
    pal = [bm_blob((0, 0.05, z + 0.55), 0.48, (0.82, 1.3, 0.85), 2), bm_blob((0, -0.48, z + 1.05), 0.27, (1, 1.05, 1.05), 2),
           bm_blob((0, -0.3, z + 0.75), 0.3, (0.9, 0.9, 1.0), 2)]
    for sx in (-1, 1):
        pal.append(bm_blob((sx * 0.33, 0.15, z + 0.62), 0.32, (0.32, 1.15, 0.6), 2))
        pal.append(bm_cyl((sx * 0.1, -0.05, z), (sx * 0.1, -0.05, z + 0.25), 0.04, 0.035, 5))
    pal.append(transformar(bm_box(0.4, 0.6, 0.1, 0, 0.0, 0), Matrix.Translation((0, 0.75, z + 0.5)) @ Matrix.Rotation(0.35, 4, "X")))
    pico = [bm_cyl((0, -0.72, z + 1.04), (0, -0.88, z + 1.0), 0.05, 0.015, 5)]
    ojos = [bm_box(0.04, 0.04, 0.05, sx * 0.17, -0.6, z + 1.13) for sx in (-1, 1)]
    pal, pico, ojos = ([transformar(b, S) for b in grupo] for grupo in (pal, pico, ojos))
    pieza([obj(est, bisel=0.04), obj([P(b, "cupula", z, z + 1.35 * E) for b in pal]), obj([P(b, "flor_amarilla") for b in pico]),
           obj([P(b, "hierro") for b in ojos])], "estatua_paloma")
    c = DATOS["estatua_paloma"]["col"]
    c.cajas.append((Vector((0, 0, 0.69)), Vector((2.0, 2.0, 1.38)), Matrix.Identity(3)))
    c.esferas.append((Vector((0, -0.15, z + 0.75 * E)), 0.6 * E))


def hacer_barrio():
    # Auto abandonado sobre ladrillos, oxidado
    empezar()
    rng = random.Random(71)
    est = [P(bm_box(4.0, 1.75, 0.75, 0, 0, 0.45), "oxido"), P(bm_box(2.2, 1.6, 0.6, 0.2, 0, 1.2), "chapa")]
    det = [P(bm_box(2.0, 1.62, 0.42, 0.2, 0, 1.28), "sombra"), P(bm_box(0.9, 1.7, 0.1, 1.55, 0, 1.12), "vidrio_osc")]
    for x in (-1.3, 1.3):
        for y in (-0.7, 0.7):
            det.append(P(bm_box(0.4, 0.25, 0.45, x, y, 0), "ladrillo"))
    for _ in range(4):
        det.append(P(bm_box(rng.uniform(0.3, 0.8), 0.02, rng.uniform(0.2, 0.4), rng.uniform(-1.5, 1.5), -0.885, rng.uniform(0.55, 0.9)),
                     rng.choice(("grafiti_rosa", "grafiti_lima", "grafiti_cian"))))
    pieza([obj(est, bisel=0.06), obj(det)], "auto_abandonado")
    DATOS["auto_abandonado"]["col"].cajas += [(Vector((0, 0, 0.82)), Vector((4.0, 1.75, 0.75)), Matrix.Identity(3)),
                                              (Vector((0.2, 0, 1.5)), Vector((2.2, 1.6, 0.6)), Matrix.Identity(3))]

    # Arco de fútbol del potrero
    empezar()
    m = [bm_cyl((x, 0, 0), (x, 0, 2.0), 0.06, 0.06, 8) for x in (-2.5, 2.5)] + [bm_cyl((-2.56, 0, 2.0), (2.56, 0, 2.0), 0.06, 0.06, 8)]
    red = [bm_cyl((x, 0, 2.0), (x, 1.2, 0), 0.015, 0.015, 4) for x in [-2.5 + k * 0.5 for k in range(11)]]
    red += [bm_cyl((-2.5, y, z), (2.5, y, z), 0.015, 0.015, 4) for y, z in ((0.4, 1.33), (0.8, 0.67), (1.2, 0.0))]
    pieza([obj([P(b, "blanco") for b in m]), obj([P(b, "persiana") for b in red])], "arco_futbol")
    DATOS["arco_futbol"]["col"].cajas.append((Vector((0, 0, 2.0)), Vector((5.2, 0.14, 0.14)), Matrix.Identity(3)))

    # Paredón de chapa (tramo de 3 m) con grafiti
    for nombre, seed in (("chapa_cerco", 81), ("chapa_cerco_b", 82)):
        empezar()
        rng = random.Random(seed)
        det = []
        n = 14
        for i in range(n):
            x = -1.5 + (i + 0.5) * 3.0 / n
            det.append(P(bm_box(3.0 / n * 0.95, 0.04 + 0.03 * (i % 2), 2.1, x, 0, 0), "oxido" if rng.random() < 0.2 else "chapa"))
        det.append(P(bm_box(0.1, 0.1, 2.2, -1.5, 0.05, 0), "metal"))
        for _ in range(2):
            w, h = rng.uniform(0.6, 1.6), rng.uniform(0.4, 0.9)
            x = rng.uniform(-1.5 + w / 2, 1.5 - w / 2)
            det.append(P(bm_box(w, 0.02, h, x, -0.045, rng.uniform(0.3, 1.1)), rng.choice(("grafiti_rosa", "grafiti_cian", "grafiti_lima"))))
        pieza([obj(det)], nombre, rango=140)
        DATOS[nombre]["col"].cajas.append((Vector((0, 0, 1.05)), Vector((3.0, 0.12, 2.1)), Matrix.Identity(3)))


def hacer_pisos():
    """Pisos especiales que van arriba de las losetas del parque (superficie a 0,2 m)."""
    T = 0.2
    # Plaza en rombo: baldosas color arena con borde de piedra y un rombo interior
    empezar()
    R = 16.0
    rombo = [(0, R), (R, 0), (0, -R), (-R, 0)]
    borde = [(0, R + 0.85), (R + 0.85, 0), (0, -R - 0.85), (-R - 0.85, 0)]
    est = [P(b, "piedra") for b in bm_aro(borde, rombo, T - 0.06, T + 0.12)]
    det = [P(bm_prisma(rombo, T - 0.05, T + 0.07), "arena"),
           P(bm_prisma([(0, 9), (9, 0), (0, -9), (-9, 0)], T + 0.07, T + 0.078), "piedra_osc"),
           P(bm_prisma([(0, 8.4), (8.4, 0), (0, -8.4), (-8.4, 0)], T + 0.072, T + 0.08), "arena")]
    pieza([obj(est, bisel=0.03), obj(det)], "plaza_rombo", sombra=False)
    DATOS["plaza_rombo"]["col"].convexos.append([Vector((x, y, z)) for x, y in borde for z in (0, T + 0.07)])

    # Plaza de las palomas: círculo de baldosas con anillos
    empezar()
    est = [P(bm_anillo(11.7, 11.0, T - 0.06, T + 0.12, 48), "piedra")]
    det = [P(bm_prisma(circulo(11.0, 48), T - 0.05, T + 0.07), "vereda"),
           P(bm_anillo(7.0, 6.4, T + 0.07, T + 0.078, 40), "piedra_osc"),
           P(bm_anillo(3.0, 2.6, T + 0.07, T + 0.078, 24), "piedra_osc")]
    pieza([obj(est, bisel=0.03), obj(det)], "plaza_palomas", sombra=False)
    DATOS["plaza_palomas"]["col"].convexos.append([Vector((x, y, z)) for x, y in circulo(11.6, 16) for z in (0, T + 0.07)])

    # Piso de goma de los juegos (rectángulo redondeado con círculos de colores)
    empezar()
    W, D, r = 30.0, 24.0, 2.5

    def redondeado(w, d, r, n=6):
        pts = []
        for cx, cy, a0 in ((w / 2 - r, d / 2 - r, 0), (-w / 2 + r, d / 2 - r, 90), (-w / 2 + r, -d / 2 + r, 180), (w / 2 - r, -d / 2 + r, 270)):
            for k in range(n + 1):
                a = math.radians(a0 + 90 * k / n)
                pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        return pts

    est = [P(b, "piedra") for b in bm_aro(redondeado(W + 1.0, D + 1.0, r + 0.5), redondeado(W, D, r), T - 0.06, T + 0.12)]
    det = [P(bm_prisma(redondeado(W, D, r), T - 0.05, T + 0.065), "goma_azul")]
    rng = random.Random(91)
    for x, y, rr, c in ((-8, -5, 3.2, "plastico_rojo"), (7, 4, 4.0, "plastico_rojo"), (-6, 6, 2.0, "plastico_verde"), (9, -6, 2.3, "plastico_amarillo"),
                        (0, 0, 1.6, "plastico_amarillo"), (-11, 1, 1.4, "plastico_verde")):
        det.append(P(bm_prisma(circulo(rr, 24, x, y), T + 0.06, T + 0.07), c))
    pieza([obj(est, bisel=0.03), obj(det)], "piso_juegos", sombra=False)


# ================================================================= construir
hacer_edificios()
hacer_mobiliario()
hacer_juegos()
hacer_animales()
hacer_barrio()
hacer_pisos()

for o in list(COL_TRABAJO.objects):
    bpy.data.objects.remove(o)
for me in list(bpy.data.meshes):
    if me.users == 0:
        bpy.data.meshes.remove(me)

stats = {}
for n, o in ASSETS.items():
    o.data.update()
    stats[n] = sum(len(p.vertices) - 2 for p in o.data.polygons)

if HACER_EXPORT:
    for n, o in ASSETS.items():
        _activar([o])
        carpeta = DIR_EDIF if DATOS[n]["carpeta"] == "edificios" else DIR_PIEZAS
        bpy.ops.export_scene.gltf(filepath=os.path.join(carpeta, n + ".glb"), export_format="GLB",
                                  use_selection=True, export_apply=True, export_yup=True,
                                  export_materials="NONE", export_cameras=False, export_lights=False)

# ================================================================= datos para Godot
# Blender (x, y, z) -> Godot (x, z, -y). Las cajas guardan centro, tamaño (en sus ejes locales) y
# los tres ejes (columnas de la base) ya en Godot.
C = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))


def g(v):
    v = C @ Vector(v)
    return [round(v.x, 4), round(v.y, 4), round(v.z, 4)]


def gd_val(v, ind=1):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(round(float(v), 4)) if isinstance(v, float) else str(v)
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, (list, tuple)):
        return "[" + ", ".join(gd_val(x, ind) for x in v) + "]"
    if isinstance(v, dict):
        pad = "\t" * ind
        return "{\n" + "".join('%s"%s": %s,\n' % (pad + "\t", k, gd_val(x, ind + 1)) for k, x in v.items()) + pad + "}"
    raise TypeError(type(v))


piezas = {}
for n in sorted(ASSETS):
    o = ASSETS[n]
    d = DATOS[n]
    col = d["col"]
    bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
    mn = Vector((min(p.x for p in bb), min(p.y for p in bb), min(p.z for p in bb)))
    mx = Vector((max(p.x for p in bb), max(p.y for p in bb), max(p.z for p in bb)))
    e = {"carpeta": d["carpeta"], "sombra": d["sombra"], "rango": float(d["rango"]), "tris": stats[n],
         "min": g((mn.x, mx.y, mn.z)), "max": g((mx.x, mn.y, mx.z))}
    for k in ("ancho", "fondo", "alto", "tipo", "ochava"):
        if k in d:
            e[k] = d[k]
    e["cajas"] = [g(c) + [round(x, 4) for x in s] + g(B.col[0]) + g(B.col[1]) + g(B.col[2]) for c, s, B in col.cajas]
    e["esferas"] = [g(c) + [round(r, 4)] for c, r in col.esferas]
    e["convexos"] = [[x for p in pts for x in g(p)] for pts in col.convexos]
    e["carteles"] = [g(p) + g(nn) + [round(w, 3), round(h, 3), t] for p, nn, w, h, t in col.carteles]
    piezas[n] = e

with open(ARCHIVO_DATOS, "w", encoding="utf-8") as f:
    f.write("class_name KitDatos\nextends RefCounted\n")
    f.write("## GENERADO por tools/blender/generar_ciudad.py (no editar a mano).\n")
    f.write("## PALETA: [nombre, color de arriba, color de abajo] en celdas de 8x8 (la arma Kit en Godot).\n")
    f.write("## PIEZAS: por pieza, su carpeta, si proyecta sombra, distancia de dibujo (0 = siempre) y en\n")
    f.write("## coordenadas de Godot: cajas [centro(3), tamaño(3), eje x(3), eje y(3), eje z(3)], esferas\n")
    f.write("## [centro(3), radio], convexos [puntos...] y carteles [posición(3), normal(3), ancho, alto, tipo].\n\n")
    f.write("const CELDAS := %d\nconst MARGEN := %r\n" % (CELLS, MARGEN))
    f.write("const PALETA := %s\n\n" % gd_val([list(p) for p in PAL]))
    f.write("const PIEZAS := %s\n" % gd_val(piezas, 0))

# ================================================================= vitrinas / renders


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
    try:
        SCENE.eevee.taa_render_samples = 32
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
    bg.inputs["Color"].default_value = (0.55, 0.7, 0.85, 1)
    bg.inputs["Strength"].default_value = 0.8
    sol = bpy.data.lights.new("sol", "SUN")
    sol.energy = 3.6
    sol.angle = math.radians(6)
    sol.color = (1.0, 0.96, 0.9)
    so = bpy.data.objects.new("sol", sol)
    so.rotation_euler = (math.radians(42), 0, math.radians(-35))
    SCENE.collection.objects.link(so)
    me = bpy.data.meshes.new("piso")
    bm = bm_box(2000, 2000, 0.01, 0, 0, -0.011)
    bm.to_mesh(me)
    bm.free()
    piso = bpy.data.objects.new("piso", me)
    SCENE.collection.objects.link(piso)
    mp = bpy.data.materials.new("piso")
    try:
        mp.use_nodes = True
    except Exception:
        pass
    bsdf = next(n for n in mp.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    a = srgb2lin(0.3)
    bsdf.inputs["Base Color"].default_value = (a, a, a * 1.05, 1)
    bsdf.inputs["Roughness"].default_value = 0.9
    me.materials.append(mp)
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.clip_end = 3000
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
    cam.location = centro + d * 600
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    R = cam.rotation_euler.to_matrix()
    loc = [R.transposed() @ (p - cam.location) for p in pts]
    x0, x1 = min(p.x for p in loc), max(p.x for p in loc)
    y0, y1 = min(p.y for p in loc), max(p.y for p in loc)
    asp = SCENE.render.resolution_x / SCENE.render.resolution_y
    cam.data.ortho_scale = max(x1 - x0, (y1 - y0) * asp) * margen
    cam.location = cam.location + R @ Vector(((x0 + x1) / 2, (y0 + y1) / 2, 0))


def fila(col, nombres, y=0.0, sep=1.0, rot=0.0):
    objs = []
    x = 0.0
    for n in nombres:
        o = ASSETS[n]
        w = o.dimensions.x
        x0 = min(Vector(c).x for c in o.bound_box)
        objs.append(instancia(n, col, (x - x0, y, 0), rot))
        x += w + sep
    return objs


if HACER_RENDER:
    cam = preparar_render()
    COL_PIEZAS.hide_render = True
    COL_EDIF.hide_render = True
    vitrinas = {}
    medios = [n for n in ASSETS if DATOS[n].get("tipo") == "medio"]
    col = coleccion("V_edificios")
    vitrinas["edificios"] = (col, fila(col, medios, 0, 1.5), -70, 18)
    col = coleccion("V_esquinas")
    objs = fila(col, [n for n in ASSETS if DATOS[n].get("tipo") == "esquina"], 0, 3.0)
    objs += fila(col, [n for n in ASSETS if DATOS[n].get("tipo") == "barrio"], 26, 1.5)
    vitrinas["esquinas_barrio"] = (col, objs, -55, 25)
    col = coleccion("V_props")
    props = [n for n in ASSETS if DATOS[n]["carpeta"] == "piezas" and not n.startswith(("plaza_", "piso_", "calesita"))]
    mitad = len(props) // 2
    objs = fila(col, props[:mitad], 0, 0.8) + fila(col, props[mitad:], -7, 0.8)
    vitrinas["props"] = (col, objs, -65, 28)
    col = coleccion("V_juegos")
    objs = [instancia("piso_juegos", col, (0, 0, 0)), instancia("calesita_base", col, (6, 3, 0.2)),
            instancia("calesita_giro", col, (6, 3, 0.2)), instancia("hamaca_marco", col, (-7, 4, 0.2)),
            instancia("hamaca_asiento", col, (-7.6, 4, 2.7)), instancia("hamaca_asiento", col, (-6.4, 4, 2.7)),
            instancia("tobogan", col, (-6, -5, 0.2), 30), instancia("subibaja_base", col, (5, -6, 0.2)),
            instancia("subibaja_tabla", col, (5, -6, 0.7)), instancia("arenero", col, (0, -1, 0.2))]
    vitrinas["juegos"] = (col, objs, -60, 35)
    # Esquina armada: dos frentes con veredas, árboles y faroles para ver el conjunto
    col = coleccion("V_esquina_armada")
    objs = [instancia("esq_cupula_a", col, (0, 0, 0))]
    x = 16
    for n in ("dep_10_a", "casa_8_a", "mod_12_a", "clas_10_a"):
        W = DATOS[n]["ancho"]
        objs.append(instancia(n, col, (x + W / 2, 0, 0)))
        x += W
    y = 16
    for n in ("clas_12_a", "dep_8_a", "ph_6_c", "dep_14_a"):
        W = DATOS[n]["ancho"]
        objs.append(instancia(n, col, (0, y + W / 2, 0), -90))
        y += W
    for k in range(6):
        objs.append(instancia(("arbol_calle_A", "arbol_calle_B", "jacaranda_calle")[k % 3], col, (6 + k * 9, -1.8, 0)))
        objs.append(instancia("cazuela", col, (6 + k * 9, -1.8, 0)))
    for k in range(3):
        objs.append(instancia("farola", col, (12 + k * 18, -2.6, 0)))
    objs.append(instancia("cartel_calle", col, (-2.6, -2.6, 0)))
    objs.append(instancia("kiosco_diarios", col, (30, -6, 0)))
    objs.append(instancia("contenedor", col, (20, -9, 0)))
    objs.append(instancia("buzon", col, (-2.4, 6, 0)))
    objs.append(instancia("bici_roja", col, (-2, 12, 0), 90))
    vitrinas["esquina_armada"] = (col, objs, -125, 24)
    col = coleccion("V_animales")
    vitrinas["animales"] = (col, fila(col, ["perro_marron", "perro_negro", "perro_blanco", "perro_echado", "perro_bolt", "cucha",
                                             "plato_hueso", "gato_naranja", "gato_negro", "gato_gris", "estatua_paloma"], 0, 0.5), -65, 20)
    for nombre, (col, objs, az, el) in vitrinas.items():
        for c2, *_ in vitrinas.values():
            c2.hide_render = c2 is not col
        encuadrar(cam, objs, az, el)
        SCENE.render.filepath = os.path.join(DIR_PREVIAS, nombre + ".png")
        bpy.ops.render.render(write_still=True)
    for c2, *_ in vitrinas.values():
        c2.hide_render = True
    COL_PIEZAS.hide_render = False
    COL_EDIF.hide_render = False

bpy.data.collections.remove(COL_TRABAJO)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_FUENTE, "ciudad.blend"))
print("RESUMEN_TRIS", sorted(stats.items(), key=lambda kv: -kv[1]))
print("TOTAL_TRIS", sum(stats.values()))
