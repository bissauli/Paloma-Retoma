# Gente de la ciudad (NPC): 22 personajes porteños, cada uno con su esqueleto.
#
#   F:/blender.exe -b --factory-startup -P tools/blender/personas.py [-- --render <carpeta>] [--solo a,b]
#
# Cada personaje sale en modelos/personas/<nombre>.glb con:
#   - un esqueleto (huesos cadera, torso, cabeza, brazo_i/d, antebrazo_i/d, muslo_i/d, pierna_i/d),
#   - la malla "Cuerpo" (una sola: un dibujo por persona) pesada a esos huesos,
#   - la malla "Sombrero" (si tiene algo que se le pueda volar de un aletazo), pesada sólo a "cabeza".
# Los colores van en los vértices (atributo "Col", sRGB tal cual: el shader del juego los usa así) y la
# coordenada U de la UV dice la zona: 0 fijo, 1 piel, 2 pelo, 3 ropa, 4 piernas. Godot puede repintar
# piel/pelo/ropa/piernas multiplicando por (color pedido / color base de la zona) y deja el resto igual.
# Además se escribe modelos/personas/personas.json con lo que Godot necesita de cada uno (alto, colores
# base de cada zona, tipo de sombrero, altura de la cabeza y de la cadera).
#
# Los sombreros se ajustan a la cabeza y el pelo de cada uno (se mide el pelo real y se agranda la copa
# hasta que lo envuelve) y al final se comprueba que ningún triángulo del sombrero corte la cabeza ni el pelo.
#
# Ejes de Blender: el frente mira a +Y (en glTF sale a -Z, que es lo que espera ModeloHumano), Z arriba,
# la derecha del personaje es +X. Piso en z = 0. Pose de reposo: parado, brazos colgando un poco abiertos.

import bpy, bmesh, math, os, sys, json, random
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "modelos", "personas")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER = None
SOLO = None
for i, a in enumerate(args):
    if a == "--render":
        RENDER = args[i + 1]
    if a == "--solo":
        SOLO = args[i + 1].split(",")
os.makedirs(OUT, exist_ok=True)

ZONAS = {"fijo": 0, "piel": 1, "pelo": 2, "ropa": 3, "piernas": 4}
PI = math.pi


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def mezcla(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def osc(c, f):
    return tuple(max(0.0, min(1.0, x * f)) for x in c)


def suave(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def sgnpow(x, e):
    return math.copysign(abs(x) ** e, x)


# =====================================================================================  malla
class Malla:
    """Geometría acumulada: vértices con peso de huesos y caras con color por esquina y zona."""

    def __init__(self):
        self.co = []
        self.peso = []
        self.caras = []   # (indices, colores por esquina, zona, suave)

    def v(self, co, peso):
        co = Vector(co)
        if callable(peso):
            peso = peso(co)
        if isinstance(peso, str):
            peso = {peso: 1.0}
        self.co.append(co)
        self.peso.append(peso)
        return len(self.co) - 1

    def cara(self, idx, col, zona, suave_=True, plano=False):
        # en los polos el quad repite un vértice: queda como triángulo (si no, Blender lo descarta y deja un agujero)
        limpio = []
        for i in idx:
            if not limpio or limpio[-1] != i:
                limpio.append(i)
        if len(limpio) > 1 and limpio[0] == limpio[-1]:
            limpio.pop()
        idx = limpio
        if len(set(idx)) < 3:
            return
        if callable(col):
            if plano:
                c = Vector((0, 0, 0))
                for i in idx:
                    c += self.co[i]
                c /= len(idx)
                cc = col(c)
                cols = [cc] * len(idx)
            else:
                cols = [col(self.co[i]) for i in idx]
        else:
            cols = [col] * len(idx)
        self.caras.append((list(idx), cols, zona, suave_))


def estampado(base, colores, celda=0.05, r=0.38, semilla=1):
    """Lunares/flores repartidos en 3D (con algo de azar) y bordes suaves: se pinta por vértice."""
    base = hexc(base) if isinstance(base, str) else base
    cols = [hexc(c) if isinstance(c, str) else c for c in colores]

    def f(co):
        cx, cy, cz = co.x / celda, co.y / celda, co.z / celda
        ix, iy, iz = math.floor(cx), math.floor(cy), math.floor(cz)
        mejor, cual = 9.0, 0
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    h = random.Random(hash((ix + dx, iy + dy, iz + dz, semilla))).random
                    px, py, pz = ix + dx + (h() - 0.5) * 0.7, iy + dy + (h() - 0.5) * 0.7, iz + dz + (h() - 0.5) * 0.7
                    d = math.sqrt((cx - px) ** 2 + (cy - py) ** 2 + (cz - pz) ** 2)
                    if d < mejor:
                        mejor, cual = d, int(h() * 1000)
        t = suave((r - mejor) / 0.12)
        return mezcla(base, cols[cual % len(cols)], t)
    return f


def superficie(m, F, nu, nv, col, zona, peso, cerrar_u=True, suave_=True, plano=False,
               polo0=False, polo1=False, tapa0=False, tapa1=False):
    """Superficie paramétrica F(u, v) (u, v en [0, 1]); filas a lo largo de v, anillos en u.
    polo0/polo1: la fila extrema es un punto (un solo vértice). tapa0/tapa1: cierra con un abanico."""
    filas = []
    nu_ = nu if cerrar_u else nu + 1
    for j in range(nv + 1):
        v = j / nv
        if (j == 0 and polo0) or (j == nv and polo1):
            idx = m.v(F(0.0, v), peso)
            filas.append([idx] * nu_)
            continue
        fila = []
        for i in range(nu_):
            u = i / nu
            fila.append(m.v(F(u, v), peso))
        filas.append(fila)
    for j in range(nv):
        a, b = filas[j], filas[j + 1]
        for i in range(nu if cerrar_u else nu):
            i2 = (i + 1) % nu_ if cerrar_u else i + 1
            m.cara([a[i], a[i2], b[i2], b[i]], col, zona, suave_, plano)
    for (cond, fila) in ((tapa0, filas[0]), (tapa1, filas[-1])):
        if cond:
            c = Vector((0, 0, 0))
            for i in fila[:nu]:
                c += m.co[i]
            c /= nu
            ci = m.v(c, peso)
            for i in range(nu):
                m.cara([ci, fila[i], fila[(i + 1) % nu_]], col, zona, suave_, plano)
    return filas


def gruesa(m, F_out, F_in, nu, nv, col, zona, peso, cerrar_u=True, suave_=True, plano=False, polo0=False, col_in=None):
    """Cáscara con espesor: cara de afuera, de adentro y el borde cosido (abierta en v=1, y en v=0 si no es polo)."""
    fo = superficie(m, F_out, nu, nv, col, zona, peso, cerrar_u, suave_, plano, polo0=polo0)
    fi = superficie(m, F_in, nu, nv, col_in or col, zona, peso, cerrar_u, suave_, plano, polo0=polo0)
    nu_ = nu if cerrar_u else nu + 1
    bordes = [(fo[-1], fi[-1])]
    if not polo0:
        bordes.append((fo[0], fi[0]))
    for (a, b) in bordes:
        for i in range(nu if cerrar_u else nu):
            i2 = (i + 1) % nu_ if cerrar_u else i + 1
            m.cara([a[i], a[i2], b[i2], b[i]], col, zona, suave_, plano)
    if not cerrar_u:
        for j in range(nv):
            for k in (0, nu):
                m.cara([fo[j][k], fo[j + 1][k], fi[j + 1][k], fi[j][k]], col, zona, suave_, plano)


def elipsoide(m, C, R, col, zona, peso, seg=16, aros=10, M=None, e1=1.0, e2=1.0, plano=False):
    """Elipsoide (o superelipsoide: e<1 lo hace más cuadrado) centrado en C con radios R y rotación M."""
    C = Vector(C)
    R = Vector(R)
    M = M or Matrix.Identity(3)
    # piezas chicas (botones, ojos, pétalos): con pocos lados alcanza
    tam = max(R.x, R.y, R.z)
    if tam < 0.012:
        seg, aros = min(seg, 6), min(aros, 4)
    elif tam < 0.03:
        seg, aros = min(seg, 10), min(aros, 6)
    elif tam < 0.06:
        seg, aros = min(seg, 12), min(aros, 8)

    def F(u, v):
        p = v * PI
        a = u * 2 * PI
        sp, cp = math.sin(p), math.cos(p)
        sa, ca = math.sin(a), math.cos(a)
        loc = Vector((R.x * sgnpow(sp, e1) * sgnpow(sa, e2), R.y * sgnpow(sp, e1) * sgnpow(ca, e2), R.z * sgnpow(cp, e1)))
        return C + M @ loc
    superficie(m, F, seg, aros, col, zona, peso, polo0=True, polo1=True, plano=plano)


def tubo(m, p0, p1, r0, r1, col, zona, peso, seg=12, tapas=("esfera", "esfera"), aplanar=1.0, frente=None, aros_tapa=3, plano=False):
    """Tubo cónico de p0 a p1 con puntas redondeadas ("esfera"), planas ("plana") o abiertas (None)."""
    seg = min(seg, 10)
    if max(r0, r1) < 0.012:
        seg, aros_tapa = min(seg, 6), min(aros_tapa, 2)
    p0, p1 = Vector(p0), Vector(p1)
    eje = (p1 - p0)
    L = eje.length
    d = eje.normalized()
    ref = Vector(frente) if frente else (Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0)))
    x = d.cross(ref).normalized()
    y = x.cross(d).normalized()
    filas = []   # (centro, radio)
    if tapas[0] == "esfera":
        for k in range(aros_tapa, 0, -1):
            ang = (PI / 2) * k / (aros_tapa + 0.0001)
            filas.append((p0 - d * r0 * math.sin(ang) * 0.9, r0 * math.cos(ang)))
    filas.append((p0, r0))
    filas.append((p1, r1))
    if tapas[1] == "esfera":
        for k in range(1, aros_tapa + 1):
            ang = (PI / 2) * k / (aros_tapa + 0.0001)
            filas.append((p1 + d * r1 * math.sin(ang) * 0.9, r1 * math.cos(ang)))
    nv = len(filas) - 1

    def F(u, v):
        j = round(v * nv)
        c, r = filas[j]
        a = u * 2 * PI
        return c + x * (math.cos(a) * r * aplanar) + y * (math.sin(a) * r)
    superficie(m, F, seg, nv, col, zona, peso, polo0=tapas[0] == "esfera", polo1=tapas[1] == "esfera",
               tapa0=tapas[0] == "plana", tapa1=tapas[1] == "plana", plano=plano)


def cilindro(m, C, r_abajo, r_arriba, alto, col, zona, peso, seg=16, M=None, ry=None, tapas=(True, True), plano=False):
    C = Vector(C)
    M = M or Matrix.Identity(3)
    k_y = (ry if ry else 1.0)

    def F(u, v):
        a = u * 2 * PI
        r = lerp(r_abajo, r_arriba, v)
        return C + M @ Vector((math.sin(a) * r, math.cos(a) * r * k_y, v * alto))
    superficie(m, F, seg, 1, col, zona, peso, tapa0=tapas[0], tapa1=tapas[1], plano=plano)


def anillo(m, C, rx, ry, r_tubo, col, zona, peso, seg=20, seg_t=6, M=None):
    """Toro (aro de anteojos, pulsera, cinta)."""
    C = Vector(C)
    M = M or Matrix.Identity(3)

    def F(u, v):
        a = u * 2 * PI
        b = v * 2 * PI
        cx, cy = math.sin(a), math.cos(a)
        rr = 1.0 + (r_tubo / max(rx, ry)) * math.cos(b)
        return C + M @ Vector((cx * rx * rr, cy * ry * rr, r_tubo * math.sin(b)))
    filas = superficie(m, F, seg, seg_t, col, zona, peso)


def loft(m, est, col, zona, peso, seg=24, n_exp=2.3, tapa0=True, tapa1=True, plano=False, arco=None):
    """Sólido por estaciones (z, cx, cy, hw, hd): secciones de superelipse. arco=(a0, a1) lo deja abierto."""
    nv = len(est) - 1

    def F(u, v):
        j = round(v * nv)
        z, cx, cy, hw, hd = est[j][:5]
        if arco:
            a = lerp(arco[0], arco[1], u)
        else:
            a = u * 2 * PI
        s, c = math.sin(a), math.cos(a)
        return Vector((cx + hw * sgnpow(s, 2.0 / n_exp), cy + hd * sgnpow(c, 2.0 / n_exp), z))
    if arco:
        return superficie(m, F, seg, nv, col, zona, peso, cerrar_u=False, plano=plano)
    return superficie(m, F, seg, nv, col, zona, peso, tapa0=tapa0, tapa1=tapa1, plano=plano)


def loft_grueso(m, est, esp, col, zona, peso, seg=24, n_exp=2.3, arco=(0.0, 2 * PI), plano=False, col_in=None):
    """Prenda con espesor (saco abierto, delantal, falda): estaciones (z, cx, cy, hw, hd)."""
    nv = len(est) - 1
    cerrado = abs(arco[1] - arco[0] - 2 * PI) < 1e-6

    def hacer(off):
        def F(u, v):
            j = round(v * nv)
            z, cx, cy, hw, hd = est[j][:5]
            a = lerp(arco[0], arco[1], u)
            s, c = math.sin(a), math.cos(a)
            return Vector((cx + (hw + off) * sgnpow(s, 2.0 / n_exp), cy + (hd + off) * sgnpow(c, 2.0 / n_exp), z))
        return F
    gruesa(m, hacer(0.0), hacer(-esp), seg, nv, col, zona, peso, cerrar_u=cerrado, plano=plano, col_in=col_in)


# =====================================================================================  personaje
class P:
    """Medidas de un cuerpo (se calculan de unos pocos parámetros)."""

    def __init__(self, alto=1.75, sexo="h", nino=False, cadera=1.0, cintura=1.0, pecho=1.0, panza=0.0,
                 busto=0.0, hombros=1.0, piernas=1.0, brazos=1.0, cabeza=1.0, encorvado=0.0, cuello=1.0):
        self.alto = alto
        self.nino = nino
        k = alto / 1.75
        if nino:
            k = alto / 1.75 * 1.05
        self.k = k
        hc = (0.93 if nino else 1.0) * cabeza
        if nino:
            hc *= (alto / 1.2) ** 0.35
        self.R = Vector((0.104, 0.112, 0.121)) * hc * 1.15
        if sexo == "m":
            self.R *= 0.96
        self.cab = Vector((0, 0.004, alto - self.R.z))
        largo_cuello = (0.05 if nino else 0.075) * cuello * (k if not nino else 0.9)
        self.cuello_z = self.cab.z - self.R.z * 0.62 - largo_cuello
        self.hombro_z = self.cuello_z - 0.035 * k
        self.cadera_z = (alto * 0.42 if nino else 0.85 * k) * piernas ** 0.25
        if sexo == "m" and not nino:
            self.cadera_z *= 1.01
        self.rodilla_z = self.cadera_z * 0.535
        self.tobillo_z = 0.075 * k
        t = self.hombro_z - self.cadera_z
        self.cintura_z = self.cadera_z + t * 0.40
        self.panza_z = self.cadera_z + t * 0.52
        self.pecho_z = self.cadera_z + t * 0.78
        base = 0.85 if nino else 1.0
        kk = k * base
        if sexo == "m":
            self.cad_hw, self.cad_hd = 0.168 * kk * cadera, 0.118 * kk * cadera
            self.cin_hw, self.cin_hd = 0.135 * kk * cintura, 0.098 * kk * cintura
            self.pec_hw, self.pec_hd = 0.158 * kk * pecho, 0.104 * kk * pecho
        else:
            self.cad_hw, self.cad_hd = 0.158 * kk * cadera, 0.112 * kk * cadera
            self.cin_hw, self.cin_hd = 0.148 * kk * cintura, 0.102 * kk * cintura
            self.pec_hw, self.pec_hd = 0.178 * kk * pecho, 0.112 * kk * pecho
        if nino:
            self.cin_hw *= 1.05
            self.cin_hd *= 1.08
        self.panza = panza * k
        self.busto = busto * k
        self.encorvado = encorvado
        self.hombro_x = self.pec_hw * 0.93 * hombros
        self.brazo_r = (0.05 if sexo == "h" else 0.044) * kk * brazos
        self.muslo_r = (0.084 if sexo == "h" else 0.08) * kk * piernas
        self.cadera_x = self.cad_hw * 0.52
        self.cuello_r = (0.046 if sexo == "h" else 0.04) * (k if not nino else 0.8)
        L = alto / 1.75 if not nino else alto / 1.5
        self.brazo_largo = 0.27 * L
        self.antebrazo_largo = 0.235 * L
        self.mano_largo = 0.105 * L
        self.pie_largo = 0.27 * (k if not nino else 0.78)
        self.sexo = sexo
        self.apertura = 0.0   # se calcula: cuánto se abren los brazos para no tocar el cuerpo

    def yoff(self, z):
        """Corrimiento hacia adelante del torso a la altura z (personas encorvadas)."""
        t = max(0.0, (z - self.cintura_z) / max(self.hombro_z - self.cintura_z, 0.01))
        return self.encorvado * 0.06 * t * t

    def ancho_en(self, z):
        """Medio ancho del torso (o la panza) a la altura z: para que los brazos no lo toquen."""
        return max(self.cad_hw, self.cin_hw + self.panza * 0.4, self.pec_hw * 0.9)


class Personaje:
    def __init__(self, nombre, p):
        self.nombre = nombre
        self.p = p
        self.m = Malla()
        self.sombrero = None   # Malla
        self.tipo_sombrero = ""
        self.color_sombrero = (1, 1, 1)
        self.base = {}   # zona -> color base
        self.cabeza_pts = []   # vértices de cabeza y pelo (para ajustar sombreros)
        self.huesos = {}
        self.extra = {}

    def zona(self, nombre, color):
        if nombre not in self.base:
            self.base[nombre] = color
        return nombre


# ------------------------------------------------------------------ huesos y pesos
def armar_huesos(pj, pose):
    p = pj.p
    ab = p.apertura
    h = {}
    h["cadera"] = (Vector((0, 0, p.cadera_z)), Vector((0, 0, p.cintura_z)), None)
    h["torso"] = (Vector((0, p.yoff(p.cintura_z), p.cintura_z)), Vector((0, p.yoff(p.hombro_z), p.cuello_z)), "cadera")
    h["cabeza"] = (Vector((0, p.yoff(p.hombro_z) + 0.005, p.cuello_z)), Vector((0, p.yoff(p.hombro_z), p.alto)), "torso")
    for lado, sx in (("i", -1), ("d", 1)):
        hom = Vector((sx * p.hombro_x, p.yoff(p.hombro_z), p.hombro_z - 0.01 * p.k))
        codo, mun = brazo_pts(p, sx, pose.get("brazo_" + lado, "colgado"))
        h["brazo_" + lado] = (hom, codo, "torso")
        h["antebrazo_" + lado] = (codo, mun, "brazo_" + lado)
        cad = Vector((sx * p.cadera_x, 0.0, p.cadera_z))
        rod = Vector((sx * p.cadera_x * 0.92, 0.008, p.rodilla_z))
        tob = Vector((sx * p.cadera_x * 0.85, -0.01, p.tobillo_z))
        h["muslo_" + lado] = (cad, rod, "cadera")
        h["pierna_" + lado] = (rod, tob, "muslo_" + lado)
    pj.huesos = h
    return h


def brazo_pts(p, sx, pose):
    hom = Vector((sx * p.hombro_x, p.yoff(p.hombro_z), p.hombro_z - 0.01 * p.k))
    ang = p.apertura
    d = Vector((sx * math.sin(ang), 0.02, -math.cos(ang))).normalized()
    codo = hom + d * p.brazo_largo
    if pose == "colgado":
        d2 = Vector((sx * math.sin(ang) * 0.7, 0.12, -1.0)).normalized()
        mun = codo + d2 * p.antebrazo_largo
    elif pose == "bandeja":   # antebrazo hacia adelante, palma arriba
        codo = hom + Vector((sx * 0.05, -0.02, -1)).normalized() * p.brazo_largo
        mun = codo + Vector((sx * 0.12, 1.0, 0.05)).normalized() * p.antebrazo_largo
    elif pose == "adelante":   # sosteniendo algo frente al cuerpo (bandoneón, mate)
        codo = hom + Vector((sx * 0.25, 0.1, -1)).normalized() * p.brazo_largo
        mun = codo + Vector((-sx * 0.35, 1.0, 0.18)).normalized() * p.antebrazo_largo
    elif pose == "codo":   # algo colgando del antebrazo (cartera)
        codo = hom + Vector((sx * 0.2, -0.05, -1)).normalized() * p.brazo_largo
        mun = codo + Vector((-sx * 0.15, 1.0, 0.25)).normalized() * p.antebrazo_largo
    else:
        mun = codo + d * p.antebrazo_largo
    return codo, mun


def peso_torso(p):
    """Del pubis a la cintura pesa a la cadera; arriba, al torso (con una mezcla suave)."""
    def f(co):
        t = suave((co.z - (p.cintura_z - 0.05 * p.k)) / (0.12 * p.k))
        return {"cadera": 1 - t, "torso": t} if 0 < t < 1 else ({"cadera": 1.0} if t <= 0 else {"torso": 1.0})
    return f


def peso_cuello(p):
    def f(co):
        t = suave((co.z - (p.cuello_z - 0.01)) / (0.06 * p.k))
        if t <= 0:
            return {"torso": 1.0}
        if t >= 1:
            return {"cabeza": 1.0}
        return {"torso": 1 - t, "cabeza": t}
    return f


def peso_falda(p, hem_z, rigidez=1.0):
    """Falda o faldón: la parte de adelante y de abajo sigue al muslo de su lado (al caminar y al sentarse)."""
    def f(co):
        t = suave((p.cadera_z + 0.02 - co.z) / max(p.cadera_z - hem_z, 0.05))
        if t <= 0:
            return {"cadera": 1.0}
        lado = "d" if co.x > 0 else "i"
        ax = min(1.0, abs(co.x) / (p.cadera_x * 1.2))
        w = t * rigidez * (0.85 + 0.15 * ax)
        pierna = 0.0
        if co.z < p.rodilla_z + 0.02:
            pierna = suave((p.rodilla_z + 0.02 - co.z) / 0.25) * 0.5 * w
        pesos = {"cadera": 1 - w, "muslo_" + lado: w - pierna}
        if pierna > 0:
            pesos["pierna_" + lado] = pierna
        return pesos
    return f


def peso_pelo_largo(p):
    def f(co):
        t = suave((p.cuello_z + 0.06 - co.z) / 0.12)
        return {"cabeza": 1 - t * 0.7, "torso": t * 0.7} if t > 0 else {"cabeza": 1.0}
    return f


# ------------------------------------------------------------------ cabeza y cara
def punto_cabeza(p, az, pol, sobre=0.0):
    """Punto de la superficie del cráneo (az 0 = frente, + hacia la derecha; pol 0 = arriba)."""
    R = p.R
    d = Vector((math.sin(pol) * math.sin(az), math.sin(pol) * math.cos(az), math.cos(pol)))
    q = Vector((d.x * R.x, d.y * R.y, d.z * R.z))
    n = Vector((d.x / R.x, d.y / R.y, d.z / R.z)).normalized()
    return p.cab + q + n * sobre, n


def base_normal(n, arriba=Vector((0, 0, 1))):
    z = n.normalized()
    x = arriba.cross(z)
    if x.length < 1e-4:
        x = Vector((1, 0, 0))
    x.normalize()
    y = z.cross(x)
    return Matrix((x, y, z)).transposed()


def cabeza(pj, piel, cfg):
    """Cráneo, cuello, orejas, nariz, ojos, cejas, boca y cachetes."""
    p, m = pj.p, pj.m
    zp = pj.zona("piel", piel)
    rubor = cfg.get("rubor", 0.35)
    mej = [punto_cabeza(p, s * 0.62, 1.78)[0] for s in (-1, 1)]

    def col_piel(co):
        d = min((co - c).length for c in mej)
        t = max(0.0, 1 - d / 0.03) * rubor
        return mezcla(piel, hexc("e8857a"), t)
    R = p.R
    C = p.cab
    mand = cfg.get("mandibula", 1.0)

    def F(u, v):
        pol = v * PI
        a = u * 2 * PI
        d = Vector((math.sin(pol) * math.sin(a), math.sin(pol) * math.cos(a), math.cos(pol)))
        # mentón un poco adelante y mandíbula más angosta abajo
        rx = R.x * (1 - 0.12 * max(0, -d.z) * (2 - mand))
        ry = R.y * (1 + 0.05 * max(0, -d.z) * max(0, d.y))
        return C + Vector((d.x * rx, d.y * ry, d.z * R.z))
    n0 = len(m.co)
    superficie(m, F, 24, 16, col_piel, zp, "cabeza", polo0=True, polo1=True)
    pj.cabeza_pts += m.co[n0:]
    # cuello
    tubo(m, (0, p.yoff(p.hombro_z), p.hombro_z - 0.04), (0, C.y - 0.01, C.z - R.z * 0.45), p.cuello_r, p.cuello_r * 0.92,
         piel, zp, peso_cuello(p), seg=12, tapas=(None, None))
    # orejas
    for s in (-1, 1):
        q, n = punto_cabeza(p, s * PI / 2 * 0.97, 1.62, -0.004)
        M = base_normal(n)
        elipsoide(m, q, (0.022 * p.R.x / 0.104, 0.009, 0.03 * p.R.z / 0.121), osc(piel, 0.96), zp, "cabeza", seg=10, aros=6,
                  M=Matrix.Rotation(s * 0.25, 3, "Z") @ Matrix.Identity(3))
    # nariz
    nz = cfg.get("nariz", 1.0)
    q, n = punto_cabeza(p, 0, 1.74, -0.004)
    elipsoide(m, q + Vector((0, 0.006, 0)), (0.013 * nz, 0.016 * nz, 0.02 * nz), osc(piel, 0.93), zp, "cabeza", seg=10, aros=7,
              M=Matrix.Rotation(-0.25, 3, "X"))
    # ojos
    ojo = hexc(cfg.get("ojo", "2a2420"))
    sep = cfg.get("sep_ojos", 0.36)
    for s in (-1, 1):
        q, n = punto_cabeza(p, s * sep, 1.55, 0.0025)
        M = base_normal(n)
        if cfg.get("ojos_cerrados"):
            elipsoide(m, q, (0.013, 0.012, 0.0035), ojo, "fijo", "cabeza", seg=10, aros=5, M=M @ Matrix.Rotation(PI / 2, 3, "Z"))
        else:
            elipsoide(m, q, (0.0135, 0.0175, 0.007), ojo, "fijo", "cabeza", seg=10, aros=6, M=M)
            q2, _ = punto_cabeza(p, s * sep + 0.045, 1.47, 0.0085)
            elipsoide(m, q2, (0.0045, 0.0045, 0.003), (1, 1, 1), "fijo", "cabeza", seg=6, aros=4, M=M)
        # ceja
        if cfg.get("cejas", True):
            q, n = punto_cabeza(p, s * (sep + 0.02), 1.27, 0.003)
            M = base_normal(n) @ Matrix.Rotation(PI / 2 - s * cfg.get("ceja_ang", 0.1), 3, "Z")
            cc = hexc(cfg.get("color_cejas", cfg.get("pelo", "3a2a20")))
            elipsoide(m, q, (0.0068, 0.023, 0.0055), cc, pj.zona("pelo", cc) if not cfg.get("cejas_fijas") else "fijo",
                      "cabeza", seg=8, aros=5, M=M)
    # boca
    q, n = punto_cabeza(p, 0, 1.98, -0.002)
    M = base_normal(n) @ Matrix.Rotation(PI / 2, 3, "Z")
    boca = hexc(cfg.get("boca", "a8524a"))
    curva = 0.045 if cfg.get("sonrisa", True) else 0.008
    ancho = 0.17 if cfg.get("sonrisa", True) else 0.12
    pts = []
    for i in range(7):
        t = i / 6 * 2 - 1
        q2, _ = punto_cabeza(p, t * ancho, 1.97 + curva * (1 - t * t) - curva * 0.5, 0.0022)
        pts.append(q2)
    for i in range(6):
        tubo(m, pts[i], pts[i + 1], 0.0034, 0.0034, boca, "fijo", "cabeza", seg=6, aros_tapa=2)


def casquete(pj, color, pmax, pmin=None, esp=0.016, R_extra=1.0, desde=None, seg=26, aros=10, zona="pelo",
             col_fn=None, peso="cabeza", centro=None, escala=(1, 1, 1), arco_az=None):
    """Casco de pelo con espesor alrededor del cráneo. pmax(az)/pmin(az): hasta qué ángulo polar llega."""
    p, m = pj.p, pj.m
    R = Vector((p.R.x * escala[0], p.R.y * escala[1], p.R.z * escala[2])) * R_extra
    C = centro or p.cab
    zn = pj.zona(zona, color) if zona != "fijo" else "fijo"

    def hacer(off):
        def F(u, v):
            a = (u * 2 * PI - PI) if not arco_az else lerp(arco_az[0], arco_az[1], u)
            p0 = pmin(a) if pmin else 0.0
            pol = lerp(p0, pmax(a), v)
            d = Vector((math.sin(pol) * math.sin(a), math.sin(pol) * math.cos(a), math.cos(pol)))
            return C + Vector((d.x * (R.x + off), d.y * (R.y + off), d.z * (R.z + off)))
        return F
    n0 = len(m.co)
    gruesa(m, hacer(esp), hacer(0.003), seg, aros, col_fn or color, zn, peso, polo0=pmin is None, cerrar_u=arco_az is None)
    pj.cabeza_pts += m.co[n0:]


def perfil(frente, lado, atras, asim=0.0):
    """Función az -> ángulo con un valor al frente, a los costados y atrás (asim: raya al costado)."""
    def f(a):
        aa = abs(a)
        if aa < PI / 2:
            r = lerp(frente, lado, suave(aa / (PI / 2)))
        else:
            r = lerp(lado, atras, suave((aa - PI / 2) / (PI / 2)))
        return r + asim * math.sin(a) * max(0, math.cos(a))
    return f


def pelo(pj, estilo, color, extra=None):
    p, m = pj.p, pj.m
    c = hexc(color)
    R, C = p.R, p.cab
    zp = pj.zona("pelo", c)
    ex = extra or {}

    def pts(n0):
        pass   # rodetes, colas, rulos: no cuentan para el tamaño del sombrero (salen por debajo o por atrás)

    if estilo == "corto":
        casquete(pj, c, perfil(0.62, 1.42, 1.95, ex.get("raya", 0.0)), esp=0.014)
    elif estilo == "raya":   # peinado al costado con jopo
        casquete(pj, c, perfil(0.66, 1.45, 1.95, -0.12), esp=0.013)
        n0 = len(m.co)
        q, n = punto_cabeza(p, 0.25, 0.42, 0.012)
        elipsoide(m, q, (0.07, 0.06, 0.028), c, zp, "cabeza", seg=14, aros=8, M=Matrix.Rotation(-0.35, 3, "X") @ Matrix.Rotation(0.3, 3, "Y"))
        pts(n0)
    elif estilo == "engominado":
        casquete(pj, c, perfil(0.6, 1.4, 1.9), esp=0.011)
    elif estilo == "revuelto":   # nene despeinado
        casquete(pj, c, perfil(0.7, 1.5, 1.95), esp=0.016)
        n0 = len(m.co)
        rnd = random.Random(7)
        for i in range(9):
            az = rnd.uniform(-1.6, 1.6) + (PI if i > 5 else 0)
            pol = rnd.uniform(0.15, 0.85)
            q, n = punto_cabeza(p, az, pol, 0.012)
            M = base_normal(n)
            cilindro(m, q - n * 0.01, 0.022, 0.002, 0.05, c, zp, "cabeza", seg=6, M=M @ Matrix.Rotation(rnd.uniform(-0.6, 0.6), 3, "X"))
        pts(n0)
    elif estilo == "pelado":   # pelado con corona de pelo a los costados y atrás
        def pmin_(a):
            aa = abs(math.atan2(math.sin(a), math.cos(a)))
            return lerp(1.38, 1.0, suave((aa - 1.2) / 1.5))

        def pmax_(a):
            aa = abs(math.atan2(math.sin(a), math.cos(a)))
            return lerp(1.45, 2.0, suave((aa - 1.2) / 1.5))
        casquete(pj, c, pmax_, pmin=pmin_, esp=0.012, arco_az=(1.15, 2 * PI - 1.15), aros=6, seg=24)
    elif estilo == "rodete":
        casquete(pj, c, perfil(0.6, 1.5, 1.85), esp=0.014)
        n0 = len(m.co)
        q, n = punto_cabeza(p, PI, ex.get("pol_rodete", 0.75), 0.03)
        elipsoide(m, q, (0.055, 0.045, 0.05), c, zp, "cabeza", seg=14, aros=10)
        pts(n0)
    elif estilo == "rulos":   # permanente de señora: rulos chicos por todo el casco
        casquete(pj, c, perfil(0.68, 1.55, 1.9), esp=0.018)
        n0 = len(m.co)
        oro = PI * (3 - math.sqrt(5))
        N = 46
        for i in range(N):
            z = 1 - (i + 0.5) / N * 1.4
            if z < -0.4:
                continue
            r = math.sqrt(max(0, 1 - z * z))
            az = ((i * oro) % (2 * PI)) - PI
            pol = math.acos(max(-1, min(1, z)))
            if pol > perfil(0.68, 1.55, 1.9)(az) - 0.05:
                continue
            q, n = punto_cabeza(p, az, pol, 0.02)
            elipsoide(m, q, (0.022, 0.022, 0.02), osc(c, 1.0 + (i % 3 - 1) * 0.05), zp, "cabeza", seg=8, aros=5)
        pts(n0)
    elif estilo in ("cola", "colitas", "trenzas", "largo", "bob", "melena"):
        if estilo == "bob":
            casquete(pj, c, perfil(0.55, 1.95, 2.05), esp=0.02, escala=(1.06, 1.04, 1.0))
        elif estilo in ("largo", "melena"):
            casquete(pj, c, perfil(0.58, 1.75, 2.0, ex.get("raya", 0.1)), esp=0.018, escala=(1.04, 1.03, 1.0))
        else:
            casquete(pj, c, perfil(0.62, 1.5, 1.9, ex.get("raya", 0.0)), esp=0.013)
        n0 = len(m.co)
        if estilo == "cola":
            q, n = punto_cabeza(p, PI, ex.get("pol_cola", 0.95), 0.014)
            elipsoide(m, q, (0.024, 0.02, 0.024), hexc(ex.get("gomita", "c8423a")), "fijo", "cabeza", seg=10, aros=6)
            pts_ = [q + Vector((0, -0.02, 0)), q + Vector((0, -0.07, -0.06)), q + Vector((0, -0.075, -0.16)), q + Vector((0, -0.05, -0.24))]
            rads = [0.03, 0.036, 0.03, 0.012]
            for i in range(3):
                tubo(m, pts_[i], pts_[i + 1], rads[i], rads[i + 1], c, zp, "cabeza", seg=10,
                     tapas=("esfera", "esfera"))
        elif estilo in ("colitas", "trenzas"):
            for s in (-1, 1):
                q, n = punto_cabeza(p, s * 1.75, 1.45, 0.016)
                elipsoide(m, q, (0.02, 0.022, 0.022), hexc(ex.get("gomita", "e86a9a")), "fijo", "cabeza", seg=10, aros=6)
                if estilo == "colitas":
                    for i in range(3):
                        cc = q + Vector((s * (0.025 + i * 0.012), -0.012 * i, -0.025 - i * 0.04))
                        elipsoide(m, cc, (0.027 - i * 0.004, 0.025 - i * 0.004, 0.032), c, zp, "cabeza", seg=10, aros=7)
                else:
                    for i in range(5):
                        cc = q + Vector((s * (0.012 + i * 0.004), 0.004 * i, -0.03 - i * 0.038))
                        elipsoide(m, cc, (0.021, 0.021, 0.026), osc(c, 1.0 if i % 2 else 0.9), zp, "cabeza", seg=10, aros=6)
                    elipsoide(m, q + Vector((s * 0.034, 0.02, -0.225)), (0.016, 0.016, 0.014), hexc(ex.get("gomita", "e86a9a")),
                              "fijo", "cabeza", seg=8, aros=5)
        elif estilo in ("largo", "melena"):
            largo = ex.get("largo", 0.3)
            ondas = ex.get("ondas", 0.0)

            def F_out(u, v, off=0.022):
                a = lerp(-PI * 0.58, PI * 0.58, u) + PI
                z = lerp(C.z - R.z * 0.15, C.z - R.z * 0.15 - largo, v)
                ens = 1.0 + 0.25 * v
                rx = (R.x * 1.04 + off) * ens
                ry = (R.y * 1.0 + off) * (1.0 - 0.25 * v)
                w = ondas * math.sin(v * 9 + u * 3) * 0.008
                return Vector((C.x + math.sin(a) * (rx + w), C.y + math.cos(a) * ry - 0.01 * v, z))

            def F_in(u, v):
                return F_out(u, v, off=0.002)
            gruesa(m, F_out, F_in, 18, 8, c, zp, peso_pelo_largo(p), cerrar_u=False)
        elif estilo == "bob":
            pass
        pts(n0)
    if ex.get("vincha"):
        n0 = len(m.co)
        anillo(m, C + Vector((0, 0, R.z * 0.42)), R.x * 1.12, R.y * 1.12, 0.009, hexc(ex["vincha"]), "fijo", "cabeza",
               seg=26, seg_t=5, M=Matrix.Rotation(0.25, 3, "X"))
        pts(n0)
    if ex.get("flor"):
        q, n = punto_cabeza(p, -1.35, 0.9, 0.03)
        for i in range(5):
            a = i * 2 * PI / 5
            elipsoide(m, q + base_normal(n) @ Vector((math.cos(a) * 0.018, math.sin(a) * 0.018, 0)), (0.016, 0.016, 0.01),
                      hexc(ex["flor"]), "fijo", "cabeza", seg=8, aros=5, M=base_normal(n))
        elipsoide(m, q + n * 0.006, (0.009, 0.009, 0.008), hexc("f2d14b"), "fijo", "cabeza", seg=8, aros=5)


def vello(pj, estilo, color):
    """Bigote y barba."""
    p, m = pj.p, pj.m
    c = hexc(color)
    zp = pj.zona("pelo", c) if "pelo" in pj.base and pj.base["pelo"] == c else "fijo"
    if estilo in ("bigote", "bigotazo", "barba", "bigote_fino"):
        for s in (-1, 1):
            q, n = punto_cabeza(p, s * 0.16, 1.88, 0.0)
            M = base_normal(n) @ Matrix.Rotation(PI / 2 + s * 0.35, 3, "Z")
            if estilo == "bigote_fino":
                elipsoide(m, q, (0.004, 0.022, 0.004), c, zp, "cabeza", seg=8, aros=5, M=M)
            else:
                g = 1.35 if estilo == "bigotazo" else 1.0
                elipsoide(m, q, (0.011 * g, 0.026 * g, 0.009 * g), c, zp, "cabeza", seg=10, aros=6, M=M)
    if estilo == "barba":
        R, C = p.R, p.cab

        def hacer(off):
            def F(u, v):
                a = lerp(-1.75, 1.75, u)
                pol = lerp(1.95 if abs(a) < 0.6 else 1.7, 2.75, v)
                pol = lerp(lerp(1.62, 2.05, suave(1 - abs(a) / 1.75) ** 2), 2.72, v)
                d = Vector((math.sin(pol) * math.sin(a), math.sin(pol) * math.cos(a), math.cos(pol)))
                return C + Vector((d.x * (R.x + off), d.y * (R.y + off * 1.3), d.z * (R.z + off)))
            return F
        n0 = len(m.co)
        gruesa(m, hacer(0.014), hacer(0.002), 20, 6, c, zp, "cabeza", cerrar_u=False)


def anteojos(pj, color="3a3030", r=0.022, sol=False):
    p, m = pj.p, pj.m
    c = hexc(color)
    for s in (-1, 1):
        q, n = punto_cabeza(p, s * 0.36, 1.55, 0.012)
        M = base_normal(n)
        anillo(m, q, r, r * 0.85, 0.0028, c, "fijo", "cabeza", seg=16, seg_t=4, M=M @ Matrix.Rotation(PI / 2, 3, "X"))
        if sol:
            elipsoide(m, q, (r, 0.003, r * 0.85), hexc("1d2228"), "fijo", "cabeza", seg=12, aros=6, M=M @ Matrix.Rotation(PI / 2, 3, "X"))
        # patilla hasta la oreja
        prev = None
        for k_ in range(5):
            az = s * lerp(0.62, 1.5, k_ / 4)
            qq, _ = punto_cabeza(p, az, 1.54, lerp(0.011, 0.005, k_ / 4))
            if prev is not None:
                tubo(m, prev, qq, 0.0025, 0.0025, c, "fijo", "cabeza", seg=5, tapas=("esfera", "esfera"), aros_tapa=1)
            prev = qq
    q1, _ = punto_cabeza(p, -0.14, 1.52, 0.012)
    q2, _ = punto_cabeza(p, 0.14, 1.52, 0.012)
    tubo(m, q1, q2, 0.0025, 0.0025, c, "fijo", "cabeza", seg=5, tapas=("plana", "plana"))
    pj.cabeza_pts += []


# ------------------------------------------------------------------ cuerpo
def torso(pj, col_arriba, col_abajo, zona_arriba="ropa", zona_abajo="piernas", linea=None, col_fn=None, plano=False,
          cuello_alto=0.0):
    """Tronco del pubis al cuello. Arriba de "linea" (la cintura del pantalón) es la ropa; abajo, el pantalón."""
    p, m = pj.p, pj.m
    k = p.k
    linea = linea if linea is not None else p.cintura_z - 0.02 * k
    za = pj.zona(zona_arriba, col_arriba) if zona_arriba != "fijo" else "fijo"
    zb = pj.zona(zona_abajo, col_abajo) if zona_abajo != "fijo" else "fijo"
    pz = p.panza
    bu = p.busto
    E = []
    E.append((p.cadera_z - 0.07 * k, 0, 0.0, p.cad_hw * 0.42, p.cad_hd * 0.5))
    E.append((p.cadera_z - 0.05 * k, 0, 0.0, p.cad_hw * 0.8, p.cad_hd * 0.84))
    E.append((p.cadera_z - 0.02 * k, 0, 0.0, p.cad_hw * 0.98, p.cad_hd * 0.98))
    E.append((p.cadera_z + 0.03 * k, 0, 0.0, p.cad_hw, p.cad_hd))
    zs = [p.cadera_z + 0.08 * k, p.cintura_z, p.panza_z, (p.panza_z + p.pecho_z) / 2, p.pecho_z,
          p.hombro_z - 0.035 * k, p.hombro_z - 0.005 * k, p.hombro_z + 0.02 * k, p.cuello_z + 0.012 * k]
    for z in zs:
        if z <= E[-1][0] + 0.005:
            continue
        t_cint = 1 - min(1, abs(z - p.cintura_z) / (0.16 * k))
        t_panza = max(0.0, 1 - abs(z - p.panza_z) / (0.17 * k)) if pz > 0 else 0
        t_pecho = max(0.0, 1 - abs(z - p.pecho_z) / (0.1 * k))
        if z < p.cintura_z:
            t = (z - p.cadera_z) / (p.cintura_z - p.cadera_z)
            hw = lerp(p.cad_hw, p.cin_hw, suave(t))
            hd = lerp(p.cad_hd, p.cin_hd, suave(t))
        elif z < p.pecho_z:
            t = (z - p.cintura_z) / (p.pecho_z - p.cintura_z)
            hw = lerp(p.cin_hw, p.pec_hw, suave(t))
            hd = lerp(p.cin_hd, p.pec_hd, suave(t))
        else:
            t = (z - p.pecho_z) / (p.cuello_z - p.pecho_z)
            if z > p.hombro_z:
                hw = lerp(p.pec_hw * 0.8, p.cuello_r * 1.3, suave((z - p.hombro_z) / (p.cuello_z + 0.012 * k - p.hombro_z)))
                hd = lerp(p.pec_hd * 0.72, p.cuello_r * 1.15, suave((z - p.hombro_z) / (p.cuello_z + 0.012 * k - p.hombro_z)))
            else:
                hw = lerp(p.pec_hw, p.pec_hw * 0.96, suave(t * 1.4))
                hd = lerp(p.pec_hd, p.pec_hd * 0.8, suave(t * 1.4))
        hd += pz * t_panza * 0.5 + bu * t_pecho * 0.45
        cy = p.yoff(z) + pz * t_panza * 0.5 + bu * t_pecho * 0.45
        hw += pz * t_panza * 0.25
        E.append((z, 0, cy, hw, hd))
    # Partir en la línea del pantalón (dos anillos a la misma altura: el corte de color queda nítido)
    abajo = [e for e in E if e[0] < linea]
    arriba = [e for e in E if e[0] >= linea]
    def interp(z):
        for i in range(len(E) - 1):
            if E[i][0] <= z <= E[i + 1][0]:
                t = (z - E[i][0]) / (E[i + 1][0] - E[i][0])
                return tuple(lerp(E[i][j], E[i + 1][j], t) if j > 0 else z for j in range(5))
        return E[-1]
    e_l = interp(linea)
    seg = pj.extra.get("seg_torso", 22)
    if abajo:
        loft(m, abajo + [e_l], col_abajo, zb, peso_torso(p), seg=seg, tapa1=False)
    E2 = [e_l] + arriba
    if col_fn and not plano:   # estampado: más anillos para que los lunares no queden en bloques
        E3 = []
        for i in range(len(E2) - 1):
            for k_ in range(3):
                t = k_ / 3
                E3.append(tuple(lerp(E2[i][j], E2[i + 1][j], t) for j in range(5)))
        E2 = E3 + [E2[-1]]
    loft(m, E2, col_fn or col_arriba, za, peso_torso(p), seg=seg, tapa0=False, plano=plano)
    pj.extra["torso_E"] = E
    if cuello_alto:
        z = p.cuello_z
        tubo(m, (0, p.yoff(z), z - 0.02), (0, p.yoff(z), z + cuello_alto), p.cuello_r * 1.25, p.cuello_r * 1.15, col_arriba, za,
             peso_cuello(p), seg=14, tapas=("plana", "plana"))
    return E


def falda_en(pj, z):
    E = pj.extra["falda_E"]
    for i in range(len(E) - 1):
        if E[i][0] <= z <= E[i + 1][0]:
            t = (z - E[i][0]) / (E[i + 1][0] - E[i][0])
            return [lerp(E[i][j], E[i + 1][j], t) for j in range(5)]
    return list(E[-1]) if z > E[-1][0] else list(E[0])


def torso_en(pj, z):
    E = pj.extra["torso_E"]
    for i in range(len(E) - 1):
        if E[i][0] <= z <= E[i + 1][0]:
            t = (z - E[i][0]) / (E[i + 1][0] - E[i][0])
            return [lerp(E[i][j], E[i + 1][j], t) for j in range(5)]
    return list(E[-1]) if z > E[-1][0] else list(E[0])


def prenda(pj, z0, z1, extra, col, zona="ropa", arco=(0, 2 * PI), esp=0.012, hem=None, peso=None, n=10, col_in=None,
           plano=False, seg=None):
    """Capa sobre el torso (saco, chaleco, delantal, campera) entre z0 (abajo) y z1 (arriba).
    hem: si baja de la cadera, hasta dónde llega y cuánto se abre (falda/faldón)."""
    p, m = pj.p, pj.m
    zn = pj.zona(zona, col if not callable(col) else (1, 1, 1)) if zona != "fijo" else "fijo"
    E = []
    for i in range(n + 1):
        z = lerp(z0, z1, i / n)
        e = torso_en(pj, z)
        E.append((z, e[1], e[2], e[3] + extra, e[4] + extra))
    if hem:
        hz, vuelo = hem
        cad = torso_en(pj, p.cadera_z + 0.03 * p.k)
        EE = []
        for i in range(6):
            t = i / 5
            z = lerp(hz, z0, t)
            w = (1 - t)
            EE.append((z, 0, cad[2] + 0.002, cad[3] + extra + vuelo * w * 1.0 + 0.004, cad[4] + extra + vuelo * w * 0.8 + 0.004))
        E = EE[:-1] + E
    loft_grueso(m, E, esp, col, zn, peso or peso_torso_falda(pj, hem), seg=seg or pj.extra.get("seg_torso", 22), arco=arco,
                col_in=col_in, plano=plano)


def peso_torso_falda(pj, hem):
    p = pj.p
    if not hem:
        return peso_torso(p)
    pf = peso_falda(p, hem[0])
    pt = peso_torso(p)

    def f(co):
        if co.z < p.cadera_z + 0.02:
            return pf(co)
        return pt(co)
    return f


def ancho_cadera(pj, z):
    """(cy, hw, hd) del cuerpo a la altura z, sin achicarse debajo de la cadera."""
    p = pj.p
    zc = p.cadera_z + 0.03 * p.k
    if z >= zc:
        e = torso_en(pj, z)
        return e[2], e[3], e[4]
    e = torso_en(pj, zc)
    return e[2], e[3], e[4]


def punto_loft(e, a, off=0.0, n_exp=2.3):
    """Punto de la sección (z, cx, cy, hw, hd) en el ángulo a (0 = frente) y su normal hacia afuera."""
    z, cx, cy, hw, hd = e[:5]

    def P(aa):
        sa, ca = math.sin(aa), math.cos(aa)
        return Vector((cx + (hw + off) * sgnpow(sa, 2.0 / n_exp), cy + (hd + off) * sgnpow(ca, 2.0 / n_exp), z))
    q = P(a)
    t = (P(a + 0.02) - P(a - 0.02))
    n = t.cross(Vector((0, 0, 1))).normalized()
    if n.dot(Vector((q.x - cx, q.y - cy, 0))) < 0:
        n = -n
    return q, n


def disco(m, q, M, rx, ry, col, peso, seg=6):
    """Calcomanía chata (abanico de un lado, mirando hacia la normal de M)."""
    n = M @ Vector((0, 0, 1))
    for lado, dz in ((1, 0.0), (-1, -0.0006)):   # dos caras (el recálculo de normales no sabe para dónde mira un disco suelto)
        c = m.v(q + n * dz, peso)
        anillo_ = [m.v(q + n * dz + M @ Vector((math.cos(i * 2 * PI / seg) * rx, math.sin(i * 2 * PI / seg) * ry, 0)), peso)
                   for i in range(seg)]
        for i in range(seg):
            m.cara([c, anillo_[i], anillo_[(i + 1) % seg]], col, "fijo", True)


def calcomanias(pj, est_fn, peso, n, colores, radio, z0, z1, semilla=1, forma="lunar", off=0.0035, arcos=None, minimo=1.6):
    """Flores o lunares chatos apoyados sobre una prenda (est_fn(z) da la sección de la prenda a esa altura)."""
    rnd = random.Random(semilla)
    puestos = []
    m = pj.m
    intentos = 0
    while len(puestos) < n and intentos < n * 60:
        intentos += 1
        z = rnd.uniform(z0, z1)
        a = rnd.uniform(-PI, PI)
        if arcos and not any(a0 <= a <= a1 for (a0, a1) in arcos):
            continue
        e = est_fn(z)
        q, nn = punto_loft(e, a, off)
        if any((q - o).length < radio * 2 * minimo for o in puestos):
            continue
        puestos.append(q)
        col = hexc(colores[len(puestos) % len(colores)])
        M = base_normal(nn) @ Matrix.Rotation(rnd.uniform(0, PI), 3, "Z")
        if forma == "flor":
            for i in range(5):
                an = i * 2 * PI / 5
                d = M @ Vector((math.cos(an) * radio * 0.5, math.sin(an) * radio * 0.5, 0))
                disco(m, q + d, M @ Matrix.Rotation(an, 3, "Z"), radio * 0.5, radio * 0.34, col, peso)
            disco(m, q + nn * 0.0012, M, radio * 0.26, radio * 0.26, hexc("f4e8c0"), peso, seg=6)
        elif forma == "hoja":
            disco(m, q, M, radio, radio * 0.38, col, peso)
        else:
            disco(m, q, M, radio, radio, col, peso, seg=10)
    return puestos


def falda(pj, hem_z, col, zona="ropa", vuelo=0.06, z_top=None, plano=False, col_fn=None, volado=None):
    """Pollera desde la cintura hasta hem_z (sigue a los muslos al caminar y al sentarse)."""
    p, m = pj.p, pj.m
    z_top = z_top or p.cintura_z
    zn = pj.zona(zona, col) if zona != "fijo" else "fijo"
    E = []
    N = 8
    for i in range(N + 1):
        t = i / N
        z = lerp(hem_z, z_top, t)
        t = suave(t) if z < p.cadera_z else t
        cy, hw, hd = ancho_cadera(pj, z)
        ext = 0.007 + vuelo * (1 - t) ** 1.3
        E.append((z, 0, cy + 0.002, hw + ext, hd + ext * 0.85))
    if col_fn:
        E2 = []
        for i in range(len(E) - 1):
            for k_ in range(3):
                t = k_ / 3
                E2.append(tuple(lerp(E[i][j], E[i + 1][j], t) for j in range(5)))
        E = E2 + [E[-1]]
    loft_grueso(m, E, 0.012, col_fn or col, zn, peso_falda(p, hem_z), seg=30 if col_fn else 24, plano=plano)
    pj.extra["falda_E"] = E
    if volado:
        E2 = []
        for i in range(3):
            t = i / 2
            z = lerp(hem_z - 0.06, hem_z + 0.03, t)
            ext = 0.012 + vuelo + 0.035 * (1 - t)
            e = torso_en(pj, p.cadera_z + 0.03 * p.k)
            E2.append((z, 0, e[2] + 0.004, max(e[3], p.cad_hw) + ext, max(e[4], p.cad_hd) + ext * 0.85))
        loft_grueso(m, E2, 0.01, hexc(volado), zn, peso_falda(p, hem_z - 0.06), seg=28)


def piernas(pj, pantalon, zona="piernas", largo="largo", piel=None, media=None, zapato="zapato", col_zapato="2b2522",
            ancho=1.0, bota=None):
    """Muslos y piernas. largo: "largo", "corto" (short/bermuda: piel abajo), "pollera" (pierna con medias)."""
    p, m = pj.p, pj.m
    k = p.k
    zz = pj.zona(zona, pantalon) if zona != "fijo" else "fijo"
    pl = callable(pantalon)
    zpiel = pj.zona("piel", piel) if piel else None
    for lado, sx in (("i", -1), ("d", 1)):
        cad, rod, _ = pj.huesos["muslo_" + lado]
        tob = pj.huesos["pierna_" + lado][1]
        rm = p.muslo_r * ancho
        rr = rm * 0.68
        rt = rm * 0.48
        if largo == "largo":
            tubo(m, cad + Vector((0, 0, 0.03)), rod, rm * 1.1, rr, pantalon, zz, "muslo_" + lado, seg=14, tapas=("esfera", "esfera"),
                 plano=pl)
            tubo(m, rod, tob + Vector((0, 0, 0.0)), rr, rt * 1.08 * ancho ** 0.5, pantalon, zz, "pierna_" + lado, seg=14,
                 tapas=("esfera", "plana"), plano=pl)
        elif largo in ("corto", "bermuda"):
            corte = 0.55 if largo == "corto" else 0.82
            mid = cad.lerp(rod, corte)
            tubo(m, cad + Vector((0, 0, 0.02)), mid, rm * 1.08, lerp(rm, rr, corte) * 1.12, pantalon, zz, "muslo_" + lado, seg=14,
                 tapas=("esfera", "plana"))
            pp = media or piel
            zpp = zpiel if not media else "fijo"
            tubo(m, cad.lerp(rod, 0.3), rod, rm * 0.86, rr * 0.95, piel, zpiel, "muslo_" + lado, seg=12, tapas=(None, "esfera"))
            tubo(m, rod, tob, rr * 0.95, rt, piel, zpiel, "pierna_" + lado, seg=12, tapas=("esfera", "plana"))
            if media:
                tubo(m, rod.lerp(tob, 0.45), tob, rr * 0.86, rt * 1.08, hexc(media), "fijo", "pierna_" + lado, seg=12,
                     tapas=("plana", "plana"))
        elif largo == "pollera":   # piernas (con medias o piel) debajo de una falda
            cc = hexc(media) if media else piel
            zc = "fijo" if media else zpiel
            # El muslo va del color de la falda: parada no se ve, y sentada la falda no alcanza a taparlo
            # entero (se veía la media color piel, como si fueran piernas desnudas)
            zf = pj.zona("ropa", pantalon)
            tubo(m, cad + Vector((0, 0, 0.02)), rod, rm * 0.95, rr * 0.92, pantalon, zf, "muslo_" + lado, seg=12, tapas=("esfera", None),
                 plano=pl)
            tubo(m, rod, tob, rr * 0.9, rt * 0.95, cc, zc, "pierna_" + lado, seg=12, tapas=("esfera", "plana"))
        if bota:
            tubo(m, rod.lerp(tob, 0.12), tob, rr * 1.12, rt * 1.25, hexc(bota), "fijo", "pierna_" + lado, seg=12,
                 tapas=("plana", "plana"))
        pie(pj, lado, sx, zapato, col_zapato)


def pie(pj, lado, sx, estilo, color):
    p, m = pj.p, pj.m
    tob = pj.huesos["pierna_" + lado][1]
    c = hexc(color)
    L = p.pie_largo
    w = 0.056 * (p.k if not p.nino else 0.82)
    if estilo == "taco":
        L *= 0.9
        elipsoide(m, (tob.x, tob.y + L * 0.32, 0.035), (w * 0.85, L * 0.42, 0.035), c, "fijo", "pierna_" + lado, seg=12, aros=7,
                  e1=0.8, e2=0.9)
        cilindro(m, (tob.x, tob.y - L * 0.05, 0.0), 0.012, 0.016, 0.06, c, "fijo", "pierna_" + lado, seg=8)
        return
    alto = 0.05 if estilo != "ojota" else 0.02
    if estilo in ("zapatilla", "botin"):
        suela = hexc("f4f2ec") if estilo == "zapatilla" else hexc("2a2a2a")
        elipsoide(m, (tob.x, tob.y + L * 0.3, 0.016), (w * 1.08, L * 0.56, 0.018), suela, "fijo", "pierna_" + lado, seg=14, aros=6,
                  e1=0.5, e2=0.8)
        elipsoide(m, (tob.x, tob.y + L * 0.26, 0.045), (w, L * 0.5, 0.042), c, "fijo", "pierna_" + lado, seg=14, aros=8, e1=0.85, e2=0.9)
        if estilo == "zapatilla":
            elipsoide(m, (tob.x, tob.y + L * 0.5, 0.066), (w * 0.55, L * 0.2, 0.016), hexc("f4f2ec"), "fijo", "pierna_" + lado, seg=10, aros=5)
    elif estilo == "ojota":
        elipsoide(m, (tob.x, tob.y + L * 0.3, 0.01), (w * 1.05, L * 0.55, 0.012), c, "fijo", "pierna_" + lado, seg=14, aros=5, e1=0.5)
        zp = "piel" if "piel" in pj.base else "fijo"
        elipsoide(m, (tob.x, tob.y + L * 0.28, 0.035), (w * 0.85, L * 0.48, 0.03), pj.base.get("piel", (0.8, 0.6, 0.5)), zp,
                  "pierna_" + lado, seg=12, aros=7)
        tubo(m, (tob.x - w * 0.8, tob.y + L * 0.2, 0.03), (tob.x + w * 0.8, tob.y + L * 0.2, 0.03), 0.008, 0.008, hexc("6b4a2a"),
             "fijo", "pierna_" + lado, seg=6)
    else:
        elipsoide(m, (tob.x, tob.y + L * 0.3, 0.012), (w * 1.05, L * 0.56, 0.013), osc(c, 0.7), "fijo", "pierna_" + lado, seg=14, aros=5, e1=0.5)
        elipsoide(m, (tob.x, tob.y + L * 0.27, 0.04), (w * 0.95, L * 0.5, 0.037), c, "fijo", "pierna_" + lado, seg=14, aros=8, e1=0.85, e2=0.9)


def brazos(pj, manga, piel, zona="ropa", corta=False, puno=None, guante=None, manga2=None):
    """Brazos con manga (corta: hasta el codo) y manos con pulgar."""
    p, m = pj.p, pj.m
    zm = pj.zona(zona, manga) if zona != "fijo" else "fijo"
    zpiel = pj.zona("piel", piel)
    for lado, sx in (("i", -1), ("d", 1)):
        hom, codo, _ = pj.huesos["brazo_" + lado]
        mun = pj.huesos["antebrazo_" + lado][1]
        r = p.brazo_r
        mg = manga2 if (manga2 and lado == "d") else manga
        # hombro redondeado (tapa la unión con el torso)
        elipsoide(m, hom + Vector((-sx * 0.008, 0, -0.006)), (r * 1.22, r * 1.25, r * 1.18), mg, zm, "brazo_" + lado, seg=12, aros=8)
        if corta:
            mid = hom.lerp(codo, 0.55)
            tubo(m, hom, mid, r * 1.3, r * 1.22, mg, zm, "brazo_" + lado, seg=12, tapas=(None, "plana"))
            tubo(m, hom, codo, r * 0.95, r * 0.85, piel, zpiel, "brazo_" + lado, seg=12, tapas=(None, "esfera"))
            tubo(m, codo, mun, r * 0.85, r * 0.66, piel, zpiel, "antebrazo_" + lado, seg=12, tapas=("esfera", "plana"))
        else:
            tubo(m, hom, codo, r * 1.2, r * 1.05, mg, zm, "brazo_" + lado, seg=12, tapas=(None, "esfera"))
            tubo(m, codo, mun, r * 1.05, r * 0.92, mg, zm, "antebrazo_" + lado, seg=12, tapas=("esfera", "plana"))
            if puno:
                tubo(m, codo.lerp(mun, 0.86), mun.lerp(codo, -0.04), r * 0.98, r * 0.98, hexc(puno), "fijo", "antebrazo_" + lado,
                     seg=12, tapas=("plana", "plana"))
        mano(pj, lado, sx, hexc(guante) if guante else piel, "fijo" if guante else zpiel)


def mano(pj, lado, sx, color, zona):
    p, m = pj.p, pj.m
    codo = pj.huesos["antebrazo_" + lado][0]
    mun = pj.huesos["antebrazo_" + lado][1]
    d = (mun - codo).normalized()
    L = p.mano_largo
    w = p.brazo_r * 1.05
    c = mun + d * (L * 0.45)
    # base: z = a lo largo de la mano, x = palma (lado de afuera)
    x = Vector((sx, 0, 0))
    x = (x - d * x.dot(d)).normalized()
    y = d.cross(x)
    M = Matrix((x, y, d)).transposed()
    elipsoide(m, c, (w * 0.62, w * 1.05, L * 0.6), color, zona, "antebrazo_" + lado, seg=12, aros=8, M=M)
    # pulgar hacia adelante
    tp = c + y * (w * 0.75) + d * (-L * 0.1) + x * (-w * 0.2)
    elipsoide(m, tp, (w * 0.32, w * 0.32, L * 0.32), color, zona, "antebrazo_" + lado, seg=8, aros=6,
              M=M @ Matrix.Rotation(-0.5, 3, "X"))


def pos_mano(pj, lado, adelante=0.0, abajo=0.5):
    codo = pj.huesos["antebrazo_" + lado][0]
    mun = pj.huesos["antebrazo_" + lado][1]
    d = (mun - codo).normalized()
    return mun + d * (pj.p.mano_largo * abajo) + Vector((0, adelante, 0)), d


def botones(pj, n, z0, z1, color="e8d9a0", x=0.0, r=0.0075, sobre=0.012, peso=None, dy=0.0):
    p, m = pj.p, pj.m
    for i in range(n):
        z = lerp(z0, z1, i / max(n - 1, 1))
        e = torso_en(pj, z)
        y = e[2] + e[4] + sobre + dy
        elipsoide(m, (x, y, z), (r, r * 0.5, r), hexc(color), "fijo", peso or peso_torso(p), seg=8, aros=5)


def cuello_camisa(pj, color, abierto=0.5, alto=0.035, zona="fijo"):
    """Cuello de camisa (dos solapas que bajan hacia adelante)."""
    p, m = pj.p, pj.m
    c = color
    zc = zona if zona == "fijo" else pj.zona(zona, c)
    z = p.cuello_z - 0.005
    for s in (-1, 1):
        a0 = s * abierto * 0.6
        a1 = s * (PI * 0.85)

        def hacer(off):
            def F(u, v):
                a = lerp(a0, a1, u)
                r = p.cuello_r * 1.28 + off + 0.008 * v
                zz = z + alto * v - 0.012 * (1 - abs(math.cos(a / 2))) * 0
                caida = 0.025 * max(0, math.cos(a)) * (1 - v)
                return Vector((math.sin(a) * r, p.yoff(z) + math.cos(a) * r * 1.05, zz - caida * 1.4))
            return F
        gruesa(m, hacer(0.004), hacer(0.0), 10, 2, c, zc, peso_cuello(p), cerrar_u=False)


def solapas(pj, color, z_abajo, ancho=0.05, zona="ropa", extra=0.014):
    """Solapas en V de un saco: dos placas que van del hombro al botón."""
    p, m = pj.p, pj.m
    zn = pj.zona(zona, color) if zona != "fijo" else "fijo"
    for s in (-1, 1):
        pts = []
        for i in range(6):
            t = i / 5
            z = lerp(p.hombro_z + 0.005, z_abajo, t)
            e = torso_en(pj, z)
            xin = lerp(p.cuello_r * 1.25, 0.0, t ** 0.9) * s
            xout = xin + s * ancho * (1 - t) ** 0.7 + s * 0.006
            pts.append((z, xin, xout, e))

        def hacer(off):
            def F(u, v):
                j = round(v * 5)
                z, xin, xout, e = pts[j]
                x = lerp(xin, xout, u)
                xx = max(-1, min(1, x / max(e[3], 0.01)))
                yy = e[2] + e[4] * math.sqrt(max(0.0, 1 - abs(xx) ** 2.3)) + extra + off
                return Vector((x, yy, z))
            return F
        gruesa(m, hacer(0.005), hacer(0.0), 4, 5, osc(color, 0.92), zn, peso_torso(p), cerrar_u=False)


def corbata(pj, color, z_abajo=None, moño=False):
    p, m = pj.p, pj.m
    c = hexc(color)
    z0 = p.cuello_z - 0.01
    e = torso_en(pj, z0)
    y0 = e[2] + e[4] + 0.008
    if moño:
        for s in (-1, 1):
            elipsoide(m, (s * 0.022, y0 + 0.004, z0 - 0.005), (0.022, 0.009, 0.015), c, "fijo", peso_torso(p), seg=10, aros=6,
                      M=Matrix.Rotation(s * 0.2, 3, "Y"))
        elipsoide(m, (0, y0 + 0.008, z0 - 0.005), (0.009, 0.009, 0.01), osc(c, 0.85), "fijo", peso_torso(p), seg=8, aros=5)
        return
    z1 = z_abajo or p.cintura_z + 0.02
    elipsoide(m, (0, y0 + 0.004, z0 - 0.008), (0.012, 0.01, 0.013), c, "fijo", peso_torso(p), seg=8, aros=5)
    pts = []
    for i in range(6):
        z = lerp(z0 - 0.015, z1, i / 5)
        e = torso_en(pj, z)
        pts.append(Vector((0, e[2] + e[4] + 0.009, z)))
    for i in range(5):
        w0 = lerp(0.012, 0.026, i / 5)
        w1 = lerp(0.012, 0.026, (i + 1) / 5)
        tubo(m, pts[i], pts[i + 1], w0, w1, c, "fijo", peso_torso(p), seg=8, tapas=("plana", "plana"), aplanar=0.35,
             frente=(1, 0, 0))


def cinturon(pj, color="2b2522", hebilla="d8c27a", z=None):
    p, m = pj.p, pj.m
    z = z or p.cintura_z - 0.02 * p.k
    e = torso_en(pj, z)
    loft_grueso(m, [(z - 0.017, e[1], e[2], e[3] + 0.006, e[4] + 0.006), (z + 0.017, e[1], e[2], e[3] + 0.006, e[4] + 0.006)],
                0.008, hexc(color), "fijo", peso_torso(p), seg=28)
    elipsoide(m, (0, e[2] + e[4] + 0.011, z), (0.016, 0.006, 0.014), hexc(hebilla), "fijo", peso_torso(p), seg=8, aros=5, e1=0.4, e2=0.4)


def bolsillo(pj, x, z, w=0.05, h=0.05, color=None, extra=0.014):
    p, m = pj.p, pj.m
    e = torso_en(pj, z)
    xx = max(-1, min(1, x / max(e[3], 0.01)))
    y = e[2] + e[4] * math.sqrt(max(0.0, 1 - abs(xx) ** 2.3)) + extra
    elipsoide(m, (x, y, z), (w / 2, 0.004, h / 2), color, "fijo", peso_torso(p), seg=8, aros=5, e1=0.3, e2=0.3)


def mochila(pj, color, solapa=None, tam=1.0, bolsa_dormir=None):
    p, m = pj.p, pj.m
    c = hexc(color)
    z = (p.pecho_z + p.cintura_z) / 2
    e = torso_en(pj, z)
    y = e[2] - e[4] - 0.07 * tam
    elipsoide(m, (0, y, z), (0.13 * tam * p.k, 0.07 * tam, 0.17 * tam * p.k), c, "fijo", "torso", seg=16, aros=10, e1=0.5, e2=0.5)
    elipsoide(m, (0, y - 0.05 * tam, z - 0.04), (0.09 * tam * p.k, 0.03 * tam, 0.08 * tam * p.k), osc(c, 0.85), "fijo", "torso",
              seg=12, aros=8, e1=0.45, e2=0.45)
    if solapa:
        elipsoide(m, (0, y + 0.0, z + 0.13 * tam * p.k), (0.125 * tam * p.k, 0.075 * tam, 0.05 * tam), hexc(solapa), "fijo", "torso",
                  seg=14, aros=8, e1=0.5, e2=0.5)
    if bolsa_dormir:
        cilindro(m, (-0.15 * p.k, y, z + 0.2 * tam * p.k), 0.055, 0.055, 0.3 * p.k, hexc(bolsa_dormir), "fijo", "torso", seg=14,
                 M=Matrix.Rotation(PI / 2, 3, "Y"))
    # tiras sobre los hombros
    for s in (-1, 1):
        x = s * p.pec_hw * 0.5
        pts = []
        for i in range(7):
            t = i / 6
            a = lerp(PI * 0.95, -0.1, t)   # de atrás por arriba del hombro hasta adelante
            zz = p.hombro_z + 0.0 + math.sin(a) * 0.02 - t * 0.12 * (t > 0.5)
            ee = torso_en(pj, min(zz, p.hombro_z))
            yy = ee[2] + math.cos(a) * (ee[4] + 0.012)
            zz = p.hombro_z + 0.012 * math.sin(a) if 0.15 < t < 0.75 else lerp(p.hombro_z, p.pecho_z - 0.06, (t - 0.75) / 0.25) if t >= 0.75 else lerp(z + 0.08, p.hombro_z, t / 0.15)
            if t >= 0.75:
                ee = torso_en(pj, zz)
                yy = ee[2] + ee[4] + 0.01
            pts.append(Vector((x, yy, zz)))
        for i in range(6):
            tubo(m, pts[i], pts[i + 1], 0.012, 0.012, osc(c, 0.8), "fijo", "torso", seg=6, tapas=("esfera", "esfera"), aplanar=0.5)


def bufanda(pj, c1, c2=None, punta=True):
    p, m = pj.p, pj.m
    z = p.cuello_z + 0.005
    col = (lambda co: hexc(c1) if (int((co.z + 1) * 40) % 2 == 0) else hexc(c2)) if c2 else hexc(c1)
    anillo(m, (0, p.yoff(z), z), p.cuello_r * 1.6, p.cuello_r * 1.55, 0.024, hexc(c1), "fijo", peso_cuello(p), seg=18, seg_t=8)
    if punta:
        e = torso_en(pj, p.pecho_z)
        x = 0.05
        tubo(m, (x, e[2] + e[4] * 0.9 + 0.02, z - 0.01), (x + 0.015, e[2] + e[4] + 0.022, p.pecho_z - 0.12), 0.026, 0.026, hexc(c1),
             "fijo", peso_torso(p), seg=8, tapas=("esfera", "plana"), aplanar=0.4, frente=(0, 1, 0))
        if c2:
            for t in (0.4, 0.75):
                zz = lerp(z - 0.01, p.pecho_z - 0.12, t)
                tubo(m, (x + 0.015 * t, e[2] + e[4] * (0.9 + 0.1 * t) + 0.021, zz + 0.012),
                     (x + 0.015 * t, e[2] + e[4] * (0.9 + 0.1 * t) + 0.021, zz - 0.012), 0.0275, 0.0275, hexc(c2), "fijo", peso_torso(p),
                     seg=8, tapas=("plana", "plana"), aplanar=0.42, frente=(0, 1, 0))


# ------------------------------------------------------------------ objetos en la mano
def obj_mano(pj, lado, fn):
    """Llama fn(pos, dir_mano, peso) para modelar algo que cuelga de la mano."""
    q, d = pos_mano(pj, lado)
    fn(q, d, "antebrazo_" + lado)


def maletin(pj, lado, color="6b4a2e"):
    p, m = pj.p, pj.m
    q, d = pos_mano(pj, lado, 0.0, 0.6)
    c = hexc(color)
    pe = "antebrazo_" + lado
    elipsoide(m, q + Vector((0, 0.01, -0.15)), (0.05, 0.19, 0.13), c, "fijo", pe, seg=14, aros=8, e1=0.25, e2=0.25)
    anillo(m, q + Vector((0, 0.01, -0.01)), 0.006, 0.04, 0.007, osc(c, 0.7), "fijo", pe, seg=12, seg_t=5,
           M=Matrix.Rotation(PI / 2, 3, "Y"))
    for s in (-1, 1):
        elipsoide(m, q + Vector((0, 0.01 + s * 0.1, -0.03)), (0.052, 0.012, 0.01), hexc("d8c27a"), "fijo", pe, seg=8, aros=4, e1=0.3, e2=0.3)


def cartera(pj, lado, color, colgando_codo=False, correa_hombro=False):
    p, m = pj.p, pj.m
    c = hexc(color)
    if colgando_codo:
        codo = pj.huesos["antebrazo_" + lado][0]
        mun = pj.huesos["antebrazo_" + lado][1]
        q = codo.lerp(mun, 0.45)
        pe = "antebrazo_" + lado
        anillo(m, q + Vector((0, 0, -0.03)), 0.008, 0.045, 0.006, osc(c, 0.75), "fijo", pe, seg=14, seg_t=5,
               M=Matrix.Rotation(PI / 2, 3, "Y"))
        elipsoide(m, q + Vector((0, 0, -0.12)), (0.045, 0.1, 0.075), c, "fijo", pe, seg=14, aros=8, e1=0.35, e2=0.35)
        elipsoide(m, q + Vector((0, 0, -0.065)), (0.003, 0.012, 0.008), hexc("d8c27a"), "fijo", pe, seg=6, aros=4)
        return
    if correa_hombro:
        sx = -1 if lado == "i" else 1
        z = p.cintura_z - 0.02
        e = torso_en(pj, z)
        x = sx * (e[3] + 0.04)
        elipsoide(m, (x, e[2] + 0.02, z), (0.04, 0.11, 0.085), c, "fijo", peso_torso(p), seg=14, aros=8, e1=0.35, e2=0.35)
        hom = pj.huesos["brazo_" + lado][0]
        tubo(m, (x, e[2] + 0.02, z + 0.07), (hom.x * 0.85, hom.y, hom.z + 0.03), 0.008, 0.008, osc(c, 0.7), "fijo", "torso", seg=6)
        tubo(m, (hom.x * 0.85, hom.y, hom.z + 0.03), (x * 0.95, e[2] + 0.06, z + 0.07), 0.008, 0.008, osc(c, 0.7), "fijo", "torso", seg=6)
        return
    q, d = pos_mano(pj, lado, 0.0, 0.6)
    pe = "antebrazo_" + lado
    elipsoide(m, q + Vector((0, 0.0, -0.12)), (0.045, 0.1, 0.08), c, "fijo", pe, seg=14, aros=8, e1=0.35, e2=0.35)


def morral(pj, color, lado="d"):
    """Bolso cruzado: la correa va del hombro contrario a la cadera."""
    p, m = pj.p, pj.m
    c = hexc(color)
    sx = 1 if lado == "d" else -1
    z = p.cadera_z + 0.04
    e = torso_en(pj, z)
    x = sx * (e[3] + 0.045)
    elipsoide(m, (x, e[2] + 0.01, z), (0.035, 0.11, 0.1), c, "fijo", peso_torso(p), seg=14, aros=8, e1=0.4, e2=0.4)
    elipsoide(m, (x + sx * 0.03, e[2] + 0.01, z + 0.05), (0.012, 0.1, 0.05), osc(c, 0.85), "fijo", peso_torso(p), seg=10, aros=6, e1=0.4, e2=0.4)
    hom = Vector((-sx * p.hombro_x * 0.75, p.yoff(p.hombro_z), p.hombro_z + 0.028))
    pts = [Vector((x, e[2] + 0.02, z + 0.09))]
    for t in (0.33, 0.66):
        zz = lerp(z + 0.09, hom.z, t)
        ee = torso_en(pj, zz)
        xx = lerp(x, hom.x, t)
        pts.append(Vector((xx, ee[2] + ee[4] + 0.016, zz)))
    pts.append(hom)
    for i in range(3):
        tubo(m, pts[i], pts[i + 1], 0.011, 0.011, osc(c, 0.75), "fijo", "torso", seg=6, aplanar=0.45)
    # por la espalda
    pts2 = [Vector((x, e[2] - 0.02, z + 0.09))]
    for t in (0.5,):
        zz = lerp(z + 0.09, hom.z, t)
        ee = torso_en(pj, zz)
        pts2.append(Vector((lerp(x, hom.x, t), ee[2] - ee[4] - 0.016, zz)))
    pts2.append(hom)
    for i in range(2):
        tubo(m, pts2[i], pts2[i + 1], 0.011, 0.011, osc(c, 0.75), "fijo", "torso", seg=6, aplanar=0.45)


# =====================================================================================  sombreros
def ajuste(pts, C, a, b, c=None, z_desde=-9.0):
    """Cuánto hay que agrandar la elipse (a, b) [o el elipsoide (a, b, c)] centrada en C para envolver los puntos."""
    s = 0.0
    for q in pts:
        if q.z < z_desde:
            continue
        dx, dy = q.x - C.x, q.y - C.y
        if c is None:
            s = max(s, math.sqrt((dx / a) ** 2 + (dy / b) ** 2))
        else:
            s = max(s, math.sqrt((dx / a) ** 2 + (dy / b) ** 2 + ((q.z - C.z) / c) ** 2))
    return s


def banda(s, C, r0, r1, alto, col, zona, peso, seg=16, M=None, ry=None):
    """Cilindro abierto (cinta, vincha, copa sin fondo): no corta la cabeza que queda adentro."""
    cilindro(s, C, r0, r1, alto, col, zona, peso, seg=seg, M=M, ry=ry, tapas=(False, False))


def sombrero(pj, tipo, color, cinta=None, extra=None):
    """Arma el sombrero y, si todavía roza algo, lo agranda de a poco hasta que no toque nada."""
    _sombrero(pj, tipo, color, cinta, extra)
    C = pj.p.cab
    for _ in range(14):
        if chequear_sombrero(pj) == 0:
            break
        for i, q in enumerate(pj.sombrero.co):
            pj.sombrero.co[i] = Vector((C.x + (q.x - C.x) * 1.015, C.y + (q.y - C.y) * 1.015, q.z + 0.0015))


def _sombrero(pj, tipo, color, cinta=None, extra=None):
    """Arma el sombrero ajustado al pelo de este personaje (nunca lo corta)."""
    p = pj.p
    ex = extra or {}
    s = Malla()
    pj.sombrero = s
    pj.tipo_sombrero = {"panama": "sombrero", "fedora": "sombrero", "cloche": "sombrero", "piluso": "sombrero",
                        "gorra": "gorra", "boina": "gorra", "lana": "gorra", "policia": "gorra",
                        "chef": "chef", "morrion": "morrion"}[tipo]
    c = hexc(color)
    pj.color_sombrero = c
    R, C = p.R, p.cab
    pts = pj.cabeza_pts
    top = max(q.z for q in pts)
    margen = 0.006
    tilt = ex.get("tilt", 0.0)
    if tipo in ("panama", "fedora", "cloche", "piluso", "chef", "policia", "morrion"):
        zb = C.z + R.z * ex.get("base", 0.38)   # altura del borde de abajo de la copa
        # la copa se apoya donde la cabeza tiene este ancho; se agranda hasta envolver todo lo que queda arriba
        k = ajuste(pts, C, R.x, R.y, z_desde=zb - 0.012)
        a, b = R.x * k + margen, R.y * k + margen
        alto = (top - zb) + ex.get("copa", 0.05)
        if tipo == "cloche":   # campana: copa redonda que baja sobre la frente
            zb = C.z + R.z * 0.32
            kk = ajuste(pts, C, R.x, R.y, R.z, z_desde=zb - 0.012)
            ra, rb, rc = R.x * kk + margen, R.y * kk + margen, R.z * kk + margen

            def hacer(off):
                def F(u, v):
                    a_ = u * 2 * PI
                    pol = lerp(0.0, math.acos(max(-1, min(1, (zb - C.z) / rc))), 1 - v)
                    return C + Vector((math.sin(pol) * math.sin(a_) * (ra + off), math.sin(pol) * math.cos(a_) * (rb + off),
                                       math.cos(pol) * (rc + off) + 0.004))
                return F
            # v=0 abajo (borde), v=1 arriba (polo)
            def Fo(u, v):
                return hacer(0.008)(u, 1 - v)

            def Fi(u, v):
                return hacer(0.0)(u, 1 - v)
            gruesa(s, Fo, Fi, 28, 9, c, "fijo", "cabeza", polo0=False)
            # ala corta caída
            zz = zb + 0.004
            r0a, r0b = ra * math.sqrt(max(0, 1 - ((zz - C.z) / rc) ** 2)), rb * math.sqrt(max(0, 1 - ((zz - C.z) / rc) ** 2))

            def ala(off):
                def F(u, v):
                    a_ = u * 2 * PI
                    w = lerp(0, 0.035, v)
                    return C + Vector((math.sin(a_) * (r0a + w + 0.004), math.cos(a_) * (r0b + w + 0.004), zz - C.z - 0.022 * v + off))
                return F
            gruesa(s, ala(0.006), ala(0.0), 28, 2, c, "fijo", "cabeza")
            if cinta:
                banda(s, (0, C.y, zz + 0.003), r0a + 0.012, r0a * 0.97 + 0.011, 0.02, hexc(cinta), "fijo", "cabeza", seg=28,
                         ry=r0b / r0a)
            if ex.get("flor"):
                q = C + Vector((-(r0a + 0.012) * 0.7, (r0b + 0.012) * 0.7, zz - C.z + 0.015))
                for i in range(5):
                    an = i * 2 * PI / 5
                    elipsoide(s, q + Vector((math.cos(an) * 0.016, 0.004, math.sin(an) * 0.016)), (0.015, 0.008, 0.015),
                              hexc(ex["flor"]), "fijo", "cabeza", seg=8, aros=5)
                elipsoide(s, q + Vector((0, 0.01, 0)), (0.008, 0.006, 0.008), hexc("f2d14b"), "fijo", "cabeza", seg=6, aros=4)
            return
        if tipo == "chef":
            alto = (top - zb) + 0.012
            banda(s, (0, C.y, zb), a + 0.002, a + 0.008, alto + 0.04, c, "fijo", "cabeza", seg=24, ry=b / a)
            # copa inflada arriba
            for i in range(7):
                an = i * 2 * PI / 7
                elipsoide(s, (math.sin(an) * a * 0.55, C.y + math.cos(an) * b * 0.55, zb + alto + 0.09),
                          (a * 0.62, b * 0.62, 0.075), c, "fijo", "cabeza", seg=12, aros=8)
            elipsoide(s, (0, C.y, zb + alto + 0.12), (a * 0.8, b * 0.8, 0.07), c, "fijo", "cabeza", seg=14, aros=8)
            return
        if tipo == "morrion":
            alto = (top - zb) + 0.2 * p.k
            banda(s, (0, C.y, zb), a + 0.004, a * 1.18, alto, c, "fijo", "cabeza", seg=20, ry=b / a)
            cilindro(s, (0, C.y, zb + alto - 0.002), a * 1.2, a * 1.2, 0.012, hexc("d8b85a"), "fijo", "cabeza", seg=20, ry=b / a)
            banda(s, (0, C.y, zb - 0.002), a + 0.01, a + 0.01, 0.018, hexc("d8b85a"), "fijo", "cabeza", seg=20, ry=b / a)
            # visera
            def vis(off):
                def F(u, v):
                    an = lerp(-1.15, 1.15, u)
                    r = lerp(1.0, 1.55, v)
                    return Vector((math.sin(an) * a * r, C.y + math.cos(an) * b * r, zb - 0.004 - 0.03 * v + off))
                return F
            gruesa(s, vis(0.006), vis(0.0), 14, 2, hexc("15161a"), "fijo", "cabeza", cerrar_u=False)
            # escarapela y penacho
            elipsoide(s, (0, C.y + b * 1.12, zb + alto * 0.62), (0.03, 0.008, 0.03), hexc("7fb4e0"), "fijo", "cabeza", seg=12, aros=6)
            elipsoide(s, (0, C.y + b * 1.13, zb + alto * 0.62), (0.013, 0.008, 0.013), hexc("f4f4f4"), "fijo", "cabeza", seg=8, aros=5)
            elipsoide(s, (0, C.y + b * 0.95, zb + alto + 0.05), (0.03, 0.03, 0.08), hexc(ex.get("penacho", "c8282e")), "fijo", "cabeza",
                      seg=10, aros=8)
            return
        if tipo == "policia":
            alto = (top - zb) + 0.012
            banda(s, (0, C.y, zb), a + 0.002, a + 0.003, 0.04, hexc("1d2230"), "fijo", "cabeza", seg=24, ry=b / a)
            banda(s, (0, C.y, zb + 0.04), a + 0.003, a * 1.25, max(alto - 0.04, 0.03), c, "fijo", "cabeza", seg=24, ry=b / a)
            cilindro(s, (0, C.y + 0.01, zb + alto - 0.004), a * 1.25, a * 1.22, 0.012, c, "fijo", "cabeza", seg=24, ry=b / a)

            def vis(off):
                def F(u, v):
                    an = lerp(-1.2, 1.2, u)
                    r = lerp(1.0, 1.6, v)
                    return Vector((math.sin(an) * (a + 0.003) * r, C.y + math.cos(an) * (b + 0.003) * r, zb - 0.02 * v + off))
                return F
            gruesa(s, vis(0.006), vis(0.0), 14, 2, hexc("111216"), "fijo", "cabeza", cerrar_u=False)
            elipsoide(s, (0, C.y + b * 1.02, zb + 0.06), (0.02, 0.006, 0.022), hexc("d8b85a"), "fijo", "cabeza", seg=10, aros=6)
            return
        # copa (panamá, fedora, piluso) + ala
        if tipo == "piluso":
            alto = (top - zb) + 0.022
        ra, rb = a, b

        def copa(off):
            def F(u, v):
                an = u * 2 * PI
                z = zb + alto * v
                hund = 0.0
                if tipo == "fedora":
                    hund = 0.02 * math.cos(an) ** 2 * suave((v - 0.6) / 0.4)
                k2 = 1 - (0.08 if tipo != "piluso" else 0.14) * v - hund
                return Vector((math.sin(an) * (ra + off) * k2, C.y + math.cos(an) * (rb + off) * k2, z))
            return F
        gruesa(s, copa(0.007), copa(0.0), 28, 3, c, "fijo", "cabeza")
        # tapa arriba (con pellizco en la fedora)
        zt = zb + alto

        def tapa(off):
            def F(u, v):
                an = u * 2 * PI
                k2 = (1 - (0.08 if tipo != "piluso" else 0.14)) * (1 - v)
                dz = -0.018 * (1 - abs(math.cos(an))) * (1 - v) if tipo == "fedora" else 0.0
                dz += -0.012 * v if tipo == "fedora" else 0.004 * math.sin(v * PI)
                return Vector((math.sin(an) * (ra + 0.007) * k2, C.y + math.cos(an) * (rb + 0.007) * k2, zt + dz + off))
            return F
        superficie(s, tapa(0.0), 28, 4, c, "fijo", "cabeza", polo1=True)
        ala_w = ex.get("ala", 0.07 if tipo == "panama" else 0.055 if tipo == "fedora" else 0.045)
        caida = ex.get("caida", 0.0 if tipo == "panama" else 0.018 if tipo == "fedora" else 0.035)

        def ala(off):
            def F(u, v):
                an = u * 2 * PI
                w = lerp(0.0, ala_w, v)
                fr = math.cos(an)
                dz = -caida * v * v * (1.0 if tipo != "fedora" else (0.4 + 0.6 * abs(fr)) * (1 if fr > -0.2 else -0.4))
                return Vector((math.sin(an) * (ra + 0.004 + w), C.y + math.cos(an) * (rb + 0.004 + w), zb - 0.001 + dz + off))
            return F
        gruesa(s, ala(0.007), ala(0.0), 32, 3, c, "fijo", "cabeza")
        if cinta:
            banda(s, (0, C.y, zb + 0.004), ra + 0.011, (ra + 0.011) * 0.985, 0.022, hexc(cinta), "fijo", "cabeza", seg=28, ry=rb / ra)
        return
    if tipo in ("gorra", "lana", "boina"):
        zb = C.z + R.z * ex.get("base", 0.2)
        kk = ajuste(pts, C, R.x, R.y, R.z, z_desde=zb - 0.012)
        ra, rb, rc = R.x * kk + margen, R.y * kk + margen, R.z * kk + margen
        if tipo == "boina":
            # vincha ajustada + plato inflado y ladeado
            zb = C.z + R.z * 0.45
            kk = ajuste(pts, C, R.x, R.y, R.z, z_desde=zb - 0.012)
            ra, rb, rc = R.x * kk + margen, R.y * kk + margen, R.z * kk + margen
            f = math.sqrt(max(0, 1 - ((zb - C.z) / rc) ** 2))
            banda(s, (0, C.y, zb - 0.004), ra * f + 0.005, ra * f + 0.003, 0.018, osc(c, 0.85), "fijo", "cabeza", seg=24, ry=rb / ra)
            alto_top = top - zb
            # boina: por dentro, un casco que copia la cabeza; por fuera, el plato inflado que se vuelca a un costado
            pz = math.acos(max(-1, min(1, (zb - C.z) / rc)))

            def boina(off, inflar):
                def F(u, v):
                    an = u * 2 * PI
                    pol = lerp(pz, 0.0, v)
                    bulto = inflar * math.sin(min(v * 1.6, 1.0) * PI / 2)
                    q = Vector((math.sin(pol) * math.sin(an) * (ra + off) * (1 + 0.42 * bulto),
                                math.sin(pol) * math.cos(an) * (rb + off) * (1 + 0.36 * bulto),
                                math.cos(pol) * (rc + off) - 0.012 * bulto * (1 - v) + 0.01 * bulto))
                    q.x += 0.022 * bulto * v
                    return C + q
                return F
            gruesa(s, boina(0.0, 1.0), boina(0.0, 0.0), 30, 9, c, "fijo", "cabeza", polo0=False)
            elipsoide(s, C + Vector((0.022, 0, rc + 0.012)), (0.006, 0.006, 0.014), osc(c, 0.8), "fijo", "cabeza", seg=6, aros=4)
            return
        pz = math.acos(max(-1, min(1, (zb - C.z) / rc)))
        gr = 0.007 if tipo == "gorra" else 0.012

        def domo(off):
            def F(u, v):
                an = u * 2 * PI
                pol = lerp(pz, 0.0, v)
                return C + Vector((math.sin(pol) * math.sin(an) * (ra + off), math.sin(pol) * math.cos(an) * (rb + off),
                                   math.cos(pol) * (rc + off)))
            return F
        gruesa(s, domo(gr), domo(0.0), 28, 8, c, "fijo", "cabeza", polo0=False)
        # tapa del polo (la gruesa deja abierto arriba si no es polo: cerramos con un botón)
        elipsoide(s, C + Vector((0, 0, rc + gr * 0.5)), (0.012, 0.012, 0.008), osc(c, 0.85), "fijo", "cabeza", seg=8, aros=5)
        f = math.sin(pz)
        if tipo == "gorra":
            col_v = hexc(ex.get("visera", color))

            def vis(off):
                def F(u, v):
                    an = lerp(-1.05, 1.05, u)
                    r = lerp(1.0, 1.75, v)
                    return Vector((math.sin(an) * ra * f * lerp(1, 0.75, v), C.y + math.cos(an) * rb * f * r, zb + 0.002 - 0.012 * v * v + off))
                return F
            gruesa(s, vis(0.006), vis(0.0), 16, 3, col_v, "fijo", "cabeza", cerrar_u=False)
        else:   # gorro de lana: puño doblado + pompón
            banda(s, (0, C.y, zb - 0.006), ra * f + 0.014, ra * f + 0.012, 0.045, osc(c, 0.9), "fijo", "cabeza", seg=24, ry=rb / ra)
            if ex.get("raya"):
                banda(s, (0, C.y, zb + 0.012), ra * f + 0.0155, ra * f + 0.0145, 0.014, hexc(ex["raya"]), "fijo", "cabeza", seg=24,
                         ry=rb / ra)
            elipsoide(s, C + Vector((0, 0, rc + 0.03)), (0.035, 0.035, 0.032), hexc(ex.get("pompon", color)), "fijo", "cabeza", seg=12, aros=8)


def chequear_sombrero(pj):
    """Cuenta triángulos del sombrero que se cruzan con la cabeza o el pelo (tiene que dar 0)."""
    if not pj.sombrero:
        return 0
    def bvh(mm, filtro):
        vs = [tuple(c) for c in mm.co]
        fs = []
        for (idx, cols, zona, sv) in mm.caras:
            if filtro is not None and not filtro(idx):
                continue
            if len(idx) == 3:
                fs.append(tuple(idx))
            else:
                fs.append((idx[0], idx[1], idx[2]))
                fs.append((idx[0], idx[2], idx[3]))
        return BVHTree.FromPolygons(vs, fs, all_triangles=True)
    pesos = pj.m.peso
    def es_cabeza(idx):
        return all(pesos[i].get("cabeza", 0) > 0.99 for i in idx)
    t1 = bvh(pj.m, es_cabeza)
    t2 = bvh(pj.sombrero, None)
    return len(t1.overlap(t2))


# =====================================================================================  personajes
PIELES = {"clara": "f1cfae", "media": "e0b48f", "trigueña": "c68e62", "morena": "a87048", "oscura": "7a4a2e", "rosada": "f2bfa6"}


def base_cuerpo(pj, piel, cara=None):
    cabeza(pj, hexc(piel), cara or {})


def construir(nombre):
    random.seed(nombre)
    f = PERSONAJES[nombre]
    pj = f()
    return pj


def nuevo(nombre, p, pose=None):
    pj = Personaje(nombre, p)
    # abrir los brazos lo justo para no tocar el torso (ni la panza, ni la cadera)
    ancho = max(p.cad_hw * 1.04, p.cin_hw + p.panza * 0.3, p.pec_hw * 0.95) + p.brazo_r * 1.25 + 0.012
    caida = p.brazo_largo + p.antebrazo_largo * 0.6
    p.apertura = max(0.06, math.asin(max(-1, min(1, (ancho - p.hombro_x) / caida))))
    pj.pose = pose or {}
    armar_huesos(pj, pj.pose)
    return pj


# --- 1. Doña Rosa: señora de tapado, rodete, anteojos y sombrerito con flor
def dona_rosa():
    p = P(1.58, "m", cadera=1.18, cintura=1.15, pecho=1.08, busto=0.03, panza=0.025, encorvado=0.5, cuello=0.8)
    pj = nuevo("dona_rosa", p, {"brazo_i": "codo"})
    piel = PIELES["clara"]
    base_cuerpo(pj, piel, {"rubor": 0.45, "nariz": 1.1, "sonrisa": True, "pelo": "dcd8d2"})
    pelo(pj, "rodete", "dcd8d2", {"pol_rodete": 1.62})
    anteojos(pj, "b08a4a")
    tap = hexc("8e3b4f")
    torso(pj, tap, tap, linea=p.cadera_z - 0.1)
    falda(pj, p.rodilla_z - 0.06, tap, vuelo=0.05)
    cuello_camisa(pj, hexc("f1ead9"), abierto=0.6, alto=0.03)
    # collar de perlas
    for i in range(15):
        a = lerp(-1.4, 1.4, i / 14)
        z = p.cuello_z - 0.035 - 0.03 * math.cos(a)
        e = torso_en(pj, z)
        elipsoide(pj.m, (math.sin(a) * (p.cuello_r * 1.5), e[2] + math.cos(a) * (p.cuello_r * 1.35 + 0.01) + 0.01, z), (0.0075,) * 3,
                  hexc("f4efe4"), "fijo", peso_torso(p), seg=6, aros=4)
    botones(pj, 4, p.cadera_z - 0.05, p.pecho_z, "3a2028")
    piernas(pj, tap, largo="pollera", piel=hexc(piel), media="e8c8b0", zapato="zapato", col_zapato="2a2226")
    brazos(pj, tap, hexc(piel), puno="6e2c3c")
    cartera(pj, "i", "3a2a2e", colgando_codo=True)
    sombrero(pj, "cloche", "efe3c8", cinta="8e3b4f", extra={"flor": "d0475a"})
    return pj


# --- 2. Abuela de los mandados: permanente lila, saquito tejido, bolsa con naranjas
def abuela():
    p = P(1.54, "m", cadera=1.2, cintura=1.2, pecho=1.1, busto=0.035, panza=0.03, encorvado=0.7, cuello=0.75)
    pj = nuevo("abuela", p, {"brazo_i": "codo"})
    piel = PIELES["media"]
    base_cuerpo(pj, piel, {"rubor": 0.4, "pelo": "c9c3d6", "sonrisa": True})
    pelo(pj, "rulos", "c9c3d6")
    anteojos(pj, "6a4a8a", r=0.024)
    vest = hexc("e3c7a0")

    torso(pj, vest, vest, linea=p.cadera_z - 0.1)
    falda(pj, p.rodilla_z - 0.1, vest, vuelo=0.06)
    calcomanias(pj, lambda z: torso_en(pj, z), peso_torso(p), 10, ["c8506a", "d87a8a"], 0.016, p.cintura_z, p.hombro_z - 0.03,
                semilla=3, forma="flor", arcos=[(-0.55, 0.55)])
    calcomanias(pj, lambda z: falda_en(pj, z), peso_falda(p, p.rodilla_z - 0.1), 34, ["c8506a", "d87a8a", "6a9a6a"], 0.017,
                p.rodilla_z - 0.07, p.cadera_z - 0.02, semilla=4, forma="flor", minimo=1.25)
    saco = hexc("8fb3c9")
    prenda(pj, p.cadera_z - 0.02, p.hombro_z + 0.01, 0.014, saco, arco=(0.5, 2 * PI - 0.5))
    botones(pj, 4, p.cintura_z - 0.02, p.pecho_z - 0.02, "f4f2ec", x=0.0, dy=-0.0)
    piernas(pj, vest, largo="pollera", piel=hexc(piel), media="d8b8a0", zapato="zapato", col_zapato="5a3a2a")
    brazos(pj, saco, hexc(piel))
    # bolsa de red con naranjas, colgando del antebrazo
    codo = pj.huesos["antebrazo_i"][0]
    mun = pj.huesos["antebrazo_i"][1]
    q = codo.lerp(mun, 0.5)
    anillo(pj.m, q + Vector((0, 0, -0.02)), 0.006, 0.04, 0.005, hexc("3a6a3a"), "fijo", "antebrazo_i", seg=12, seg_t=4,
           M=Matrix.Rotation(PI / 2, 3, "Y"))
    for i, (dx, dy, dz) in enumerate([(0, -0.03, -0.12), (0.0, 0.035, -0.12), (0.0, 0.0, -0.17), (0.0, -0.03, -0.2), (0, 0.035, -0.2)]):
        elipsoide(pj.m, q + Vector((dx, dy, dz)), (0.036,) * 3, hexc("f08a2a" if i != 2 else "e8c040"), "fijo", "antebrazo_i", seg=10, aros=7)
    elipsoide(pj.m, q + Vector((0, 0, -0.15)), (0.052, 0.075, 0.1), hexc("3a6a3a"), "fijo", "antebrazo_i", seg=10, aros=7)
    return pj


# --- 3. Jubilado: boina, chaleco tejido, bigote canoso y bastón
def jubilado():
    p = P(1.68, "h", panza=0.04, encorvado=0.6, cadera=1.02, cuello=0.85)
    pj = nuevo("jubilado", p)
    piel = PIELES["trigueña"]
    base_cuerpo(pj, piel, {"rubor": 0.25, "nariz": 1.3, "sonrisa": False, "pelo": "d8d6d0", "ceja_ang": -0.05})
    pelo(pj, "pelado", "d8d6d0")
    vello(pj, "bigotazo", "e4e2dc")
    cam = hexc("a9c4dd")
    pan = hexc("6a6e78")
    torso(pj, cam, pan)
    chal = hexc("8a6a4a")

    def tejido(co):
        return osc(chal, 0.88) if int(co.z * 60) % 2 == 0 else chal
    prenda(pj, p.cadera_z - 0.01, p.hombro_z - 0.01, 0.012, tejido, arco=(0.45, 2 * PI - 0.45), plano=True)
    cuello_camisa(pj, cam, abierto=0.5)
    botones(pj, 4, p.cadera_z + 0.02, p.pecho_z - 0.03, "4a3a2a", dy=0.002)
    cinturon(pj)
    piernas(pj, pan, zapato="zapato", col_zapato="3a2a22")
    brazos(pj, cam, hexc(piel))
    # bastón en la mano izquierda
    q, d = pos_mano(pj, "i", 0, 0.45)
    tubo(pj.m, q + Vector((0, 0.02, 0.05)), Vector((q.x - 0.02, q.y + 0.12, 0.0)), 0.011, 0.01, hexc("5a3a22"), "fijo", "antebrazo_i",
         seg=8, tapas=("esfera", "plana"))
    tubo(pj.m, q + Vector((0, 0.02, 0.05)), q + Vector((0, -0.05, 0.06)), 0.012, 0.012, hexc("5a3a22"), "fijo", "antebrazo_i", seg=8)
    sombrero(pj, "boina", "3c4049")
    return pj


# --- 4. Turista gringo: camisa hawaiana, bermudas, cámara y panamá
def turista_gringo():
    p = P(1.82, "h", panza=0.075, cadera=1.08, cintura=1.15, pecho=1.05)
    pj = nuevo("turista_gringo", p)
    piel = PIELES["rosada"]
    base_cuerpo(pj, piel, {"rubor": 0.7, "pelo": "e0c070", "nariz": 1.15})
    pelo(pj, "corto", "e0c070")
    anteojos(pj, "202020", sol=True, r=0.025)
    base = hexc("3fb6b0")

    bermuda = hexc("c8b48a")
    torso(pj, base, bermuda, linea=p.cadera_z + 0.03)
    calcomanias(pj, lambda z: torso_en(pj, z), peso_torso(p), 34, ["f6d55c", "e86a5a", "f4f0e4"], 0.032, p.cadera_z + 0.06,
                p.hombro_z - 0.03, semilla=5, forma="flor", off=0.0045, minimo=1.15)
    calcomanias(pj, lambda z: torso_en(pj, z), peso_torso(p), 30, ["2f8a6a", "3f9a7a"], 0.028, p.cadera_z + 0.05, p.hombro_z - 0.02,
                semilla=6, forma="hoja", minimo=0.9, off=0.003)
    cuello_camisa(pj, base, abierto=0.9, alto=0.03, zona="ropa")
    botones(pj, 4, p.cadera_z + 0.08, p.pecho_z, "f4f2ec")
    piernas(pj, bermuda, largo="bermuda", piel=hexc(piel), media="f4f4f0", zapato="zapatilla", col_zapato="f0f0f0")
    brazos(pj, base, hexc(piel), corta=True)
    # cámara colgada
    e = torso_en(pj, p.pecho_z - 0.05)
    y = e[2] + e[4] + 0.03
    elipsoide(pj.m, (0, y, p.pecho_z - 0.06), (0.06, 0.025, 0.04), hexc("26282e"), "fijo", peso_torso(p), seg=12, aros=6, e1=0.3, e2=0.3)
    cilindro(pj.m, (0.015, y + 0.02, p.pecho_z - 0.065), 0.022, 0.02, 0.035, hexc("3a3c44"), "fijo", peso_torso(p), seg=12,
             M=Matrix.Rotation(-PI / 2, 3, "X"))
    for s in (-1, 1):
        tubo(pj.m, (s * 0.055, y - 0.01, p.pecho_z - 0.04), (s * p.cuello_r * 1.25, p.yoff(p.cuello_z), p.cuello_z - 0.005), 0.005, 0.005,
             hexc("26282e"), "fijo", peso_torso(p), seg=5)
    sombrero(pj, "panama", "e9d49a", cinta="3a3a3a")
    return pj


# --- 5. Mochilera: cola de caballo pelirroja, gorra, mochila grande con bolsa de dormir
def mochilera():
    p = P(1.66, "m", piernas=1.0)
    pj = nuevo("mochilera", p)
    piel = PIELES["clara"]
    base_cuerpo(pj, piel, {"rubor": 0.5, "pelo": "b5562e", "boca": "c0605a"})
    # pecas
    pelo(pj, "cola", "b5562e", {"pol_cola": 1.45, "gomita": "2a6a3a"})
    rem = hexc("e3b23c")
    jean = hexc("4f6f9e")
    torso(pj, rem, jean, linea=p.cintura_z - 0.01)
    piernas(pj, jean, largo="corto", piel=hexc(piel), media="f0ece0", zapato="botin", col_zapato="7a5a3a")
    brazos(pj, rem, hexc(piel), corta=True)
    mochila(pj, "3f6f5a", solapa="2f5a4a", tam=1.25, bolsa_dormir="c86a3a")
    # riñonera
    z = p.cintura_z - 0.03
    e = torso_en(pj, z)
    elipsoide(pj.m, (0.04, e[2] + e[4] + 0.03, z), (0.08, 0.03, 0.045), hexc("2a3a5a"), "fijo", peso_torso(p), seg=12, aros=6, e1=0.5, e2=0.5)
    cinturon(pj, "2a3a5a", "1a1a1a", z=z)
    sombrero(pj, "gorra", "5a8f5a", extra={"visera": "4a7a4a", "base": 0.33})
    return pj


# --- 6. Oficinista: traje azul, corbata roja, maletín
def oficinista():
    p = P(1.78, "h", pecho=1.05, cintura=0.95)
    pj = nuevo("oficinista", p)
    piel = PIELES["media"]
    base_cuerpo(pj, piel, {"rubor": 0.2, "pelo": "3a2a20", "sonrisa": False})
    pelo(pj, "raya", "3a2a20")
    traje = hexc("2f3b55")
    cam = hexc("f4f2ec")
    torso(pj, cam, traje)
    corbata(pj, "b8323a")
    prenda(pj, p.cadera_z - 0.07, p.hombro_z + 0.004, 0.014, traje, arco=(0.38, 2 * PI - 0.38))
    solapas(pj, traje, p.cintura_z + 0.03, ancho=0.05)
    cuello_camisa(pj, cam, abierto=0.45, alto=0.028)
    botones(pj, 2, p.cintura_z - 0.03, p.cintura_z + 0.02, "1a1e2a", x=0.0, sobre=0.026)
    bolsillo(pj, -0.09, p.pecho_z, 0.045, 0.015, hexc("f4f2ec"), extra=0.026)
    piernas(pj, traje, zapato="zapato", col_zapato="1a1614")
    brazos(pj, traje, hexc(piel), puno="f4f2ec")
    maletin(pj, "i")
    return pj


# --- 7. Oficinista mujer: blazer, pollera tubo, cartera al hombro, carré
def oficinista_mujer():
    p = P(1.68, "m", cadera=1.05)
    pj = nuevo("oficinista_mujer", p)
    piel = PIELES["trigueña"]
    base_cuerpo(pj, piel, {"rubor": 0.35, "pelo": "2a1e1a", "boca": "b0404a"})
    pelo(pj, "bob", "2a1e1a")
    blazer = hexc("4a4e5a")
    cam = hexc("f0e8e0")
    torso(pj, cam, blazer, linea=p.cadera_z - 0.05)
    falda(pj, p.rodilla_z - 0.02, blazer, vuelo=0.0)
    prenda(pj, p.cadera_z - 0.05, p.hombro_z + 0.004, 0.014, blazer, arco=(0.42, 2 * PI - 0.42))
    solapas(pj, blazer, p.cintura_z + 0.02, ancho=0.04)
    botones(pj, 1, p.cintura_z, p.cintura_z, "1a1a1a", sobre=0.026)
    piernas(pj, blazer, largo="pollera", piel=hexc(piel), media="c89a7a", zapato="taco", col_zapato="1a1a1a")
    brazos(pj, blazer, hexc(piel), puno="f0e8e0")
    cartera(pj, "d", "1e1e22", correa_hombro=True)
    # aros
    for s in (-1, 1):
        q, n = punto_cabeza(p, s * PI / 2, 1.85, 0.004)
        elipsoide(pj.m, q, (0.006,) * 3, hexc("e0c060"), "fijo", "cabeza", seg=6, aros=4)
    return pj


# --- 8. Escolar: guardapolvo blanco con moño azul y mochila
def escolar():
    p = P(1.22, "h", nino=True)
    pj = nuevo("escolar", p)
    piel = PIELES["media"]
    base_cuerpo(pj, piel, {"rubor": 0.5, "pelo": "4a3020", "sep_ojos": 0.4})
    pelo(pj, "revuelto", "4a3020")
    gp = hexc("f4f4f0")
    pan = hexc("2d3a5c")
    torso(pj, gp, gp, linea=p.cadera_z - 0.1)
    prenda(pj, p.cadera_z - 0.02, p.hombro_z - 0.03, 0.012, gp, arco=(0, 2 * PI), hem=(p.rodilla_z - 0.02, 0.04), esp=0.01)
    corbata(pj, "2d4f9a", moño=True)
    cuello_camisa(pj, gp, abierto=0.4, alto=0.03, zona="ropa")
    botones(pj, 3, p.cintura_z - 0.05, p.pecho_z, "dcdcd8")
    piernas(pj, pan, zapato="zapatilla", col_zapato="3a5aa0")
    brazos(pj, gp, hexc(piel))
    mochila(pj, "c8423a", solapa="a8322a", tam=0.9)
    return pj


# --- 9. Escolar nena: guardapolvo, trenzas, mochila violeta
def escolar_nena():
    p = P(1.18, "m", nino=True)
    pj = nuevo("escolar_nena", p)
    piel = PIELES["morena"]
    base_cuerpo(pj, piel, {"rubor": 0.45, "pelo": "1e1612", "sep_ojos": 0.4})
    pelo(pj, "trenzas", "1e1612", {"gomita": "e86a9a"})
    gp = hexc("f4f4f0")
    torso(pj, gp, gp, linea=p.cadera_z - 0.1)
    prenda(pj, p.cadera_z - 0.02, p.hombro_z - 0.03, 0.012, gp, arco=(0, 2 * PI), hem=(p.rodilla_z - 0.02, 0.05), esp=0.01)
    corbata(pj, "2d4f9a", moño=True)
    cuello_camisa(pj, gp, abierto=0.4, alto=0.03, zona="ropa")
    piernas(pj, gp, largo="pollera", piel=hexc(piel), media="f4f4f0", zapato="zapato", col_zapato="1a1a1a")
    brazos(pj, gp, hexc(piel))
    mochila(pj, "8a5ac8", solapa="e86a9a", tam=0.9)
    return pj


# --- 10. Pibe de la pelota: camiseta a rayas, short, medias altas, gorra
def pibe():
    p = P(1.25, "h", nino=True)
    pj = nuevo("pibe", p)
    piel = PIELES["trigueña"]
    base_cuerpo(pj, piel, {"rubor": 0.45, "pelo": "2a1e16", "sep_ojos": 0.4})
    pelo(pj, "corto", "2a1e16")
    roja = hexc("d33a3a")
    blanca = hexc("f2f2f2")

    def rayas(co):
        a = math.atan2(co.x, co.y)
        return roja if int((a + PI) / (2 * PI) * 14) % 2 == 0 else blanca
    short = hexc("1e1e24")
    torso(pj, roja, short, col_fn=rayas, plano=True, linea=p.cadera_z + 0.0)
    cuello_camisa(pj, blanca, abierto=0.5, alto=0.025)
    piernas(pj, short, largo="corto", piel=hexc(piel), media="d33a3a", zapato="botin", col_zapato="1a1a1a")
    brazos(pj, roja, hexc(piel), corta=True)
    sombrero(pj, "gorra", "2d5aa8", extra={"visera": "1e3a78", "base": 0.33})
    return pj


# --- 11. Mozo de café: chaleco negro, moño, delantal largo, bandeja con cortado
def mozo():
    p = P(1.75, "h", pecho=1.02)
    pj = nuevo("mozo", p, {"brazo_i": "bandeja"})
    piel = PIELES["media"]
    base_cuerpo(pj, piel, {"rubor": 0.25, "pelo": "15120f", "sonrisa": True, "ceja_ang": 0.2})
    pelo(pj, "engominado", "15120f")
    vello(pj, "bigote_fino", "15120f")
    cam = hexc("f6f4ee")
    neg = hexc("1e2026")
    torso(pj, cam, neg)
    chaleco = neg
    prenda(pj, p.cintura_z - 0.03, p.hombro_z - 0.01, 0.012, chaleco, arco=(0.5, 2 * PI - 0.5), zona="fijo")
    botones(pj, 3, p.cintura_z, p.pecho_z - 0.03, "c8c8c8", sobre=0.016)
    corbata(pj, "121216", moño=True)
    cuello_camisa(pj, cam, abierto=0.35, alto=0.028)
    # delantal largo blanco
    z = p.cintura_z - 0.02
    e = torso_en(pj, z)
    E = []
    for i in range(7):
        t = i / 6
        zz = lerp(p.rodilla_z - 0.18, z, t)
        cy, hw, hd = ancho_cadera(pj, zz)
        ext = 0.014 + 0.03 * (1 - t)
        E.append((zz, 0, cy, hw + ext, hd + ext))
    loft_grueso(pj.m, E, 0.01, cam, pj.zona("ropa", cam), peso_falda(p, p.rodilla_z - 0.18), seg=22, arco=(-1.55, 1.55))
    cinturon(pj, "f6f4ee", "f6f4ee", z=z)
    piernas(pj, neg, zona="fijo", zapato="zapato", col_zapato="0e0e10")
    brazos(pj, cam, hexc(piel))
    # servilleta en el antebrazo y bandeja con un cortado y un vaso de soda
    codo = pj.huesos["antebrazo_i"][0]
    mun = pj.huesos["antebrazo_i"][1]
    q = codo.lerp(mun, 0.35)
    elipsoide(pj.m, q + Vector((0, 0, -0.035)), (0.05, 0.06, 0.035), cam, "fijo", "antebrazo_i", seg=10, aros=6, e1=0.6, e2=0.6)
    qm, d = pos_mano(pj, "i", 0, 0.4)
    bz = qm.z + 0.035
    cilindro(pj.m, (qm.x, qm.y, bz), 0.2, 0.2, 0.012, hexc("c9ccd1"), "fijo", "antebrazo_i", seg=24)
    anillo(pj.m, (qm.x, qm.y, bz + 0.012), 0.2, 0.2, 0.006, hexc("a9acb1"), "fijo", "antebrazo_i", seg=28, seg_t=4)
    cilindro(pj.m, (qm.x - 0.05, qm.y + 0.04, bz + 0.012), 0.05, 0.05, 0.006, hexc("f4f4f0"), "fijo", "antebrazo_i", seg=14)
    cilindro(pj.m, (qm.x - 0.05, qm.y + 0.04, bz + 0.018), 0.022, 0.028, 0.045, hexc("f4f4f0"), "fijo", "antebrazo_i", seg=12)
    cilindro(pj.m, (qm.x - 0.05, qm.y + 0.04, bz + 0.058), 0.02, 0.02, 0.004, hexc("6a3e22"), "fijo", "antebrazo_i", seg=12)
    cilindro(pj.m, (qm.x + 0.07, qm.y - 0.02, bz + 0.012), 0.027, 0.032, 0.1, hexc("bfe0e8"), "fijo", "antebrazo_i", seg=12)
    return pj


# --- 12. Granadero: casaca azul con cuello rojo, pantalón blanco, botas, morrión
def granadero():
    p = P(1.85, "h", pecho=1.08, cintura=0.95, hombros=1.02)
    pj = nuevo("granadero", p)
    piel = PIELES["media"]
    base_cuerpo(pj, piel, {"rubor": 0.2, "pelo": "2a1e16", "sonrisa": False, "ceja_ang": -0.15})
    pelo(pj, "engominado", "2a1e16")
    vello(pj, "bigote", "2a1e16")
    azul = hexc("1f2a55")
    blanco = hexc("ecebe6")
    torso(pj, azul, blanco, linea=p.cadera_z - 0.03, cuello_alto=0.045)
    # cuello y pechera rojos, alamares dorados
    rojo = hexc("b8282e")
    cilindro(pj.m, (0, p.yoff(p.cuello_z), p.cuello_z + 0.005), p.cuello_r * 1.33, p.cuello_r * 1.25, 0.04, rojo, "fijo", peso_cuello(p), seg=16)
    for i in range(6):
        z = lerp(p.cintura_z + 0.02, p.pecho_z + 0.03, i / 5)
        e = torso_en(pj, z)
        for s in (-1, 1):
            tubo(pj.m, (s * 0.012, e[2] + e[4] + 0.004, z), (s * 0.06, e[2] + e[4] * 0.93 + 0.004, z), 0.005, 0.005, hexc("d8b85a"),
                 "fijo", peso_torso(p), seg=6)
    botones(pj, 6, p.cintura_z + 0.02, p.pecho_z + 0.03, "d8b85a", sobre=0.008)
    # faldones de la casaca
    prenda(pj, p.cadera_z - 0.02, p.cintura_z - 0.02, 0.012, azul, arco=(0.6, 2 * PI - 0.6), hem=(p.cadera_z - 0.14, 0.03))
    cinturon(pj, "f4f4f0", "d8b85a")
    # charreteras
    for s in (-1, 1):
        hom = pj.huesos["brazo_" + ("d" if s > 0 else "i")][0]
        elipsoide(pj.m, hom + Vector((-s * 0.015, 0, 0.045)), (0.05, 0.045, 0.012), hexc("d8b85a"), "fijo", "torso", seg=12, aros=6)
    piernas(pj, blanco, zapato="botin", col_zapato="121214", bota="121214")
    brazos(pj, azul, hexc(piel), guante="f4f4f0", puno="b8282e")
    # sable en la cadera izquierda
    z = p.cadera_z
    e = torso_en(pj, z)
    tubo(pj.m, (-(e[3] + 0.03), e[2] + 0.02, z + 0.02), (-(e[3] + 0.06), e[2] - 0.1, z - 0.62), 0.016, 0.013, hexc("2a2a30"), "fijo",
         "cadera", seg=8, tapas=("plana", "esfera"))
    tubo(pj.m, (-(e[3] + 0.03), e[2] + 0.02, z + 0.02), (-(e[3] + 0.02), e[2] + 0.06, z + 0.12), 0.012, 0.012, hexc("d8b85a"), "fijo",
         "cadera", seg=8)
    sombrero(pj, "morrion", "15161a", extra={"base": 0.3})
    return pj


# --- 13. Bandoneonista: fedora, chaleco, pañuelo, bandoneón (va sentado)
def bandoneonista():
    p = P(1.74, "h", panza=0.03)
    pj = nuevo("bandoneonista", p, {"brazo_i": "adelante", "brazo_d": "adelante"})
    piel = PIELES["trigueña"]
    base_cuerpo(pj, piel, {"rubor": 0.25, "pelo": "1e1a18", "ojos_cerrados": True, "sonrisa": False})
    pelo(pj, "engominado", "1e1a18")
    vello(pj, "bigote", "1e1a18")
    cam = hexc("f0ece2")
    gris = hexc("3e4048")
    torso(pj, cam, gris)
    prenda(pj, p.cintura_z - 0.05, p.hombro_z - 0.01, 0.012, hexc("5a5048"), arco=(0.5, 2 * PI - 0.5), zona="fijo")
    botones(pj, 4, p.cintura_z - 0.03, p.pecho_z - 0.03, "1a1a1a", sobre=0.016)
    bufanda(pj, "f4f2ec", punta=False)
    piernas(pj, gris, zapato="zapato", col_zapato="141212")
    brazos(pj, cam, hexc(piel))
    # bandoneón: una tapa en cada mano y el fuelle entre las dos (pesa a los dos antebrazos: se estira)
    qi, _ = pos_mano(pj, "i", 0, 0.5)
    qd, _ = pos_mano(pj, "d", 0, 0.5)
    cz = (qi.z + qd.z) / 2
    cy = (qi.y + qd.y) / 2
    for lado, q in (("i", qi), ("d", qd)):
        sx = -1 if lado == "i" else 1
        elipsoide(pj.m, (q.x - sx * 0.015, cy, cz), (0.035, 0.1, 0.1), hexc("16141a"), "fijo", "antebrazo_" + lado, seg=14, aros=8, e1=0.3, e2=0.3)
        for i in range(10):
            a = i * 2 * PI / 10
            elipsoide(pj.m, (q.x + sx * 0.022, cy + math.cos(a) * 0.05, cz + math.sin(a) * 0.05), (0.004, 0.009, 0.009), hexc("efe6d4"),
                      "fijo", "antebrazo_" + lado, seg=6, aros=4)
    n = 7
    for i in range(n):
        x0 = lerp(qi.x + 0.02, qd.x - 0.02, i / n)
        x1 = lerp(qi.x + 0.02, qd.x - 0.02, (i + 1) / n)
        t = (i + 0.5) / n

        def peso_fuelle(co, t=t):
            return {"antebrazo_i": 1 - t, "antebrazo_d": t}
        col = hexc("a8202a") if i % 2 == 0 else hexc("e8dcc8")
        elipsoide(pj.m, ((x0 + x1) / 2, cy, cz), ((x1 - x0) / 2 + 0.003, 0.088, 0.088), col, "fijo", peso_fuelle, seg=10, aros=6,
                  e1=0.3, e2=0.3)
    sombrero(pj, "fedora", "35363c", cinta="111114")
    return pj


# --- 14. Bailarina de tango: vestido rojo con volado, flor en el pelo, tacos
def bailarina():
    p = P(1.7, "m", cintura=0.9, cadera=1.05, busto=0.02)
    pj = nuevo("bailarina", p)
    piel = PIELES["media"]
    base_cuerpo(pj, piel, {"rubor": 0.45, "pelo": "15100e", "boca": "b0202a"})
    pelo(pj, "rodete", "15100e", {"pol_rodete": 1.35, "flor": "d0202e"})
    rojo = hexc("c0283a")
    torso(pj, rojo, rojo, linea=p.cadera_z - 0.1)
    falda(pj, p.rodilla_z - 0.1, rojo, vuelo=0.07, volado="9a1a2a")
    piernas(pj, rojo, largo="pollera", piel=hexc(piel), media="3a2a2a", zapato="taco", col_zapato="141212")
    brazos(pj, rojo, hexc(piel), corta=True)
    for s in (-1, 1):
        q, n = punto_cabeza(p, s * PI / 2, 1.85, 0.004)
        elipsoide(pj.m, q + Vector((0, 0, -0.02)), (0.008, 0.008, 0.02), hexc("e0c060"), "fijo", "cabeza", seg=6, aros=5)
    return pj


# --- 15. Hincha de la Selección: camiseta albiceleste, bufanda, gorro de lana con pompón
def hincha():
    p = P(1.76, "h", panza=0.02, pecho=1.05)
    pj = nuevo("hincha", p)
    piel = PIELES["trigueña"]
    base_cuerpo(pj, piel, {"rubor": 0.3, "pelo": "2a1e16", "sonrisa": True})
    pelo(pj, "corto", "2a1e16")
    vello(pj, "barba", "2a1e16")
    cel = hexc("7fb8e4")
    bl = hexc("f6f6f2")

    def rayas(co):
        a = math.atan2(co.x, co.y)
        return cel if int((a + PI) / (2 * PI) * 14 + 0.5) % 2 == 0 else bl
    jean = hexc("3a4f74")
    torso(pj, cel, jean, col_fn=rayas, plano=True)
    cuello_camisa(pj, bl, abierto=0.5, alto=0.022)
    piernas(pj, jean, zapato="zapatilla", col_zapato="2a2a2e")
    brazos(pj, cel, hexc(piel), corta=True)
    bufanda(pj, "7fb8e4", "f6f6f2")
    sombrero(pj, "lana", "7fb8e4", extra={"pompon": "f6f6f2", "raya": "f6f6f2", "base": 0.3})
    return pj


# --- 16. Agente de tránsito: chaleco flúo, gorra de plato, silbato
def agente():
    p = P(1.8, "m", cadera=1.05)
    pj = nuevo("agente", p)
    piel = PIELES["morena"]
    base_cuerpo(pj, piel, {"rubor": 0.3, "pelo": "1a1412", "sonrisa": False})
    pelo(pj, "cola", "1a1412", {"pol_cola": 1.5, "gomita": "1a1412"})
    az = hexc("2a3550")
    torso(pj, az, az)
    fluo = hexc("d8e04a")
    prenda(pj, p.cintura_z - 0.06, p.hombro_z - 0.005, 0.016, fluo, arco=(0.32, 2 * PI - 0.32), zona="fijo")
    for z in (p.cintura_z + 0.01, p.pecho_z - 0.02):
        e = torso_en(pj, z)
        loft_grueso(pj.m, [(z - 0.012, e[1], e[2], e[3] + 0.018, e[4] + 0.018), (z + 0.012, e[1], e[2], e[3] + 0.018, e[4] + 0.018)],
                    0.004, hexc("d8dcdc"), "fijo", peso_torso(p), seg=22, arco=(0.34, 2 * PI - 0.34))
    cuello_camisa(pj, az, abierto=0.4, alto=0.028, zona="ropa")
    cinturon(pj, "141414", "c8c8c8")
    piernas(pj, az, zapato="botin", col_zapato="141414")
    brazos(pj, az, hexc(piel), guante="f4f4f4")
    # silbato colgando
    e = torso_en(pj, p.pecho_z)
    elipsoide(pj.m, (0.03, e[2] + e[4] + 0.022, p.pecho_z + 0.01), (0.008, 0.016, 0.008), hexc("c8c8d0"), "fijo", peso_torso(p), seg=8, aros=5)
    sombrero(pj, "policia", "2a3550", extra={"base": 0.32})
    return pj


# --- 17. Barrendero: uniforme naranja con bandas, gorra, escoba
def barrendero():
    p = P(1.72, "h", panza=0.035)
    pj = nuevo("barrendero", p)
    piel = PIELES["morena"]
    base_cuerpo(pj, piel, {"rubor": 0.25, "pelo": "1e1814", "sonrisa": True})
    pelo(pj, "corto", "1e1814")
    vello(pj, "bigote", "1e1814")
    nar = hexc("e2762f")
    torso(pj, nar, nar)
    for z in (p.cintura_z + 0.02, p.pecho_z - 0.01):
        e = torso_en(pj, z)
        loft_grueso(pj.m, [(z - 0.012, e[1], e[2], e[3] + 0.004, e[4] + 0.004), (z + 0.012, e[1], e[2], e[3] + 0.004, e[4] + 0.004)],
                    0.004, hexc("d8dcdc"), "fijo", peso_torso(p), seg=22)
    cuello_camisa(pj, nar, abierto=0.5, alto=0.025, zona="ropa")
    piernas(pj, nar, zona="ropa", zapato="botin", col_zapato="2a2a2a")
    for lado, sx in (("i", -1), ("d", 1)):
        rod = pj.huesos["pierna_" + lado][0]
        tob = pj.huesos["pierna_" + lado][1]
        tubo(pj.m, rod.lerp(tob, 0.55), rod.lerp(tob, 0.68), p.muslo_r * 0.43, p.muslo_r * 0.41, hexc("d8dcdc"), "fijo", "pierna_" + lado,
             seg=12, tapas=("plana", "plana"))
    brazos(pj, nar, hexc(piel), guante="3a6a3a")
    # escoba en la mano izquierda
    q, d = pos_mano(pj, "i", 0, 0.45)
    top = q + Vector((0.0, 0.03, 0.32))
    bot = Vector((q.x - 0.02, q.y + 0.18, 0.08))
    tubo(pj.m, top, bot, 0.012, 0.012, hexc("a07a4a"), "fijo", "antebrazo_i", seg=8)
    elipsoide(pj.m, bot + Vector((0, 0.01, -0.03)), (0.15, 0.04, 0.05), hexc("c8a040"), "fijo", "antebrazo_i", seg=12, aros=6, e1=0.5, e2=0.6)
    elipsoide(pj.m, bot + Vector((0, 0.0, 0.015)), (0.14, 0.035, 0.02), hexc("3a6a3a"), "fijo", "antebrazo_i", seg=12, aros=6, e1=0.3, e2=0.3)
    sombrero(pj, "gorra", "e2762f", extra={"visera": "c8602a", "base": 0.33})
    return pj


# --- 18. Cocinero: chaqueta cruzada, pañuelo, delantal, pantalón a cuadros, gorro alto
def cocinero():
    p = P(1.76, "h", panza=0.06, cintura=1.1)
    pj = nuevo("cocinero", p)
    piel = PIELES["clara"]
    base_cuerpo(pj, piel, {"rubor": 0.55, "pelo": "6a4a32", "sonrisa": True, "nariz": 1.2})
    pelo(pj, "corto", "6a4a32")
    vello(pj, "bigotazo", "6a4a32")
    bl = hexc("f6f4ee")

    def cuadros(co):
        a = int((co.x + 2) * 40) % 2
        b = int((co.z + 2) * 40) % 2
        return hexc("2a2a2e") if (a + b) % 2 == 0 else hexc("dcdcdc")
    torso(pj, bl, bl, cuello_alto=0.035)
    for i in range(3):
        z = lerp(p.cintura_z + 0.02, p.pecho_z, i / 2)
        for x in (-0.05, 0.05):
            e = torso_en(pj, z)
            elipsoide(pj.m, (x, e[2] + e[4] * 0.96 + 0.008, z), (0.008, 0.004, 0.008), hexc("dcdcd4"), "fijo", peso_torso(p), seg=8, aros=5)
    bufanda(pj, "c8423a", punta=False)
    # delantal desde la cintura
    z = p.cintura_z - 0.02
    E = []
    for i in range(7):
        t = i / 6
        zz = lerp(p.rodilla_z - 0.08, z, t)
        cy, hw, hd = ancho_cadera(pj, zz)
        ext = 0.014 + 0.03 * (1 - t)
        E.append((zz, 0, cy, hw + ext, hd + ext))
    loft_grueso(pj.m, E, 0.01, hexc("e8e2d4"), "fijo", peso_falda(p, p.rodilla_z - 0.08), seg=22, arco=(-1.5, 1.5))
    for i in range(10):
        a = lerp(-1.5, 1.5, i / 9)
    piernas(pj, cuadros, zona="fijo", zapato="zapato", col_zapato="1a1a1a")
    brazos(pj, bl, hexc(piel))
    sombrero(pj, "chef", "fbfaf6", extra={"base": 0.3})
    pj.extra["cuadros"] = True
    return pj


# --- 19. Almacenero: pelado con bigote, guardapolvo gris, lápiz en la oreja
def almacenero():
    p = P(1.7, "h", panza=0.08, cintura=1.15, cadera=1.05)
    pj = nuevo("almacenero", p)
    piel = PIELES["media"]
    base_cuerpo(pj, piel, {"rubor": 0.35, "pelo": "2a2420", "sonrisa": True, "nariz": 1.25})
    pelo(pj, "pelado", "2a2420")
    vello(pj, "bigotazo", "2a2420")
    gp = hexc("a8a290")
    pan = hexc("3a3f4a")
    torso(pj, hexc("f0ece0"), pan)
    prenda(pj, p.cadera_z - 0.02, p.hombro_z + 0.004, 0.014, gp, arco=(0.3, 2 * PI - 0.3), hem=(p.rodilla_z + 0.04, 0.03))
    solapas(pj, gp, p.pecho_z - 0.06, ancho=0.035)
    botones(pj, 4, p.cadera_z - 0.05, p.pecho_z - 0.07, "3a3a3a", sobre=0.026)
    bolsillo(pj, -0.08, p.pecho_z, 0.05, 0.05, osc(gp, 0.9), extra=0.026)
    # lápiz en la oreja derecha
    q, n = punto_cabeza(p, PI / 2 * 0.95, 1.4, 0.012)
    tubo(pj.m, q + Vector((0, 0.05, 0.0)), q + Vector((0, -0.05, 0.015)), 0.0045, 0.0045, hexc("e8c040"), "fijo", "cabeza", seg=6)
    piernas(pj, pan, zapato="zapato", col_zapato="2a2220")
    brazos(pj, gp, hexc(piel))
    return pj


# --- 20. Estudiante: campera de jean, auriculares, mate y termo
def estudiante():
    p = P(1.65, "m")
    pj = nuevo("estudiante", p, {"brazo_d": "adelante"})
    piel = PIELES["trigueña"]
    base_cuerpo(pj, piel, {"rubor": 0.4, "pelo": "5a3a24", "sonrisa": True})
    pelo(pj, "largo", "5a3a24", {"largo": 0.3, "ondas": 1.0, "raya": 0.15})
    rem = hexc("f2e8d8")
    neg = hexc("2a2a30")
    torso(pj, rem, neg)
    jean = hexc("6a8fbe")
    prenda(pj, p.cadera_z + 0.0, p.hombro_z + 0.004, 0.014, jean, arco=(0.45, 2 * PI - 0.45))
    cuello_camisa(pj, osc(jean, 0.9), abierto=0.9, alto=0.03, zona="ropa")
    piernas(pj, neg, zapato="zapatilla", col_zapato="f4f4f4")
    brazos(pj, jean, hexc(piel))
    # auriculares
    R, C = p.R, p.cab
    for s in (-1, 1):
        q, n = punto_cabeza(p, s * PI / 2, 1.6, 0.03)
        elipsoide(pj.m, q, (0.016, 0.03, 0.03), hexc("26262c"), "fijo", "cabeza", seg=10, aros=6, M=Matrix.Rotation(PI / 2, 3, "Y"))
    def arco_(off):
        def F(u, v):
            a = lerp(-PI / 2, PI / 2, u)
            r = 1.0 + 0.0
            return C + Vector((math.sin(a) * (R.x + 0.04 + off), -0.005, math.cos(a) * (R.z + 0.035 + off) + 0.0))
        return F
    n0 = len(pj.m.co)
    def Fo(u, v):
        return arco_(0.006)(u, v) + Vector((0, lerp(-0.01, 0.01, v), 0))

    def Fi(u, v):
        return arco_(0.0)(u, v) + Vector((0, lerp(-0.01, 0.01, v), 0))
    gruesa(pj.m, Fo, Fi, 14, 1, hexc("26262c"), "fijo", "cabeza", cerrar_u=False)
    # mate en la mano derecha (adelante) y termo bajo el brazo izquierdo
    q, d = pos_mano(pj, "d", 0.0, 0.3)
    elipsoide(pj.m, q + Vector((-0.02, 0.0, 0.06)), (0.035, 0.035, 0.042), hexc("8a5a32"), "fijo", "antebrazo_d", seg=12, aros=8)
    cilindro(pj.m, q + Vector((-0.02, 0.0, 0.09)), 0.028, 0.03, 0.012, hexc("c8c8c8"), "fijo", "antebrazo_d", seg=12)
    elipsoide(pj.m, q + Vector((-0.02, 0.0, 0.1)), (0.022, 0.022, 0.006), hexc("5a8a3a"), "fijo", "antebrazo_d", seg=10, aros=5)
    tubo(pj.m, q + Vector((-0.02, 0.0, 0.08)), q + Vector((-0.04, -0.03, 0.17)), 0.004, 0.004, hexc("c8c8c8"), "fijo", "antebrazo_d", seg=6)
    hom = pj.huesos["brazo_i"][0]
    e = torso_en(pj, p.pecho_z - 0.08)
    cilindro(pj.m, (-(e[3] + 0.03), e[2] + 0.02, p.cintura_z - 0.05), 0.04, 0.04, 0.3, hexc("3a6a8a"), "fijo", "torso", seg=14,
             M=Matrix.Rotation(0.2, 3, "X"))
    return pj


# --- 21. Artesano: rastas con vincha, barba, poncho a rayas, morral, ojotas
def artesano():
    p = P(1.78, "h", pecho=0.98)
    pj = nuevo("artesano", p)
    piel = PIELES["trigueña"]
    base_cuerpo(pj, piel, {"rubor": 0.3, "pelo": "4a3220", "sonrisa": True, "ojos_cerrados": False})
    pelo(pj, "rodete", "4a3220", {"pol_rodete": 0.55})
    vello(pj, "barba", "4a3220")
    cam = hexc("e8dcc0")
    pan = hexc("6a5a3a")
    torso(pj, cam, pan)
    rojo = hexc("a8322a")

    def guarda(co):
        z = co.z
        b = int((z - p.cintura_z) * 40)
        return [rojo, hexc("e8c040"), hexc("2a2a30"), rojo, rojo][b % 5]
    # chaleco tejido abierto a rayas horizontales
    prenda(pj, p.cadera_z - 0.07, p.hombro_z + 0.004, 0.016, guarda, arco=(0.5, 2 * PI - 0.5), plano=True, zona="fijo")
    cuello_camisa(pj, cam, abierto=0.8, alto=0.02)
    piernas(pj, pan, zapato="ojota", col_zapato="6b4a2a", ancho=1.12)
    brazos(pj, cam, hexc(piel), corta=False)
    morral(pj, "8a6a3a", lado="i")
    # pulseras
    for lado in ("i", "d"):
        codo = pj.huesos["antebrazo_" + lado][0]
        mun = pj.huesos["antebrazo_" + lado][1]
    return pj


# --- 22. Farmacéutica: guardapolvo blanco, ambo verde agua, estetoscopio, anteojos
def farmaceutica():
    p = P(1.67, "m")
    pj = nuevo("farmaceutica", p)
    piel = PIELES["clara"]
    base_cuerpo(pj, piel, {"rubor": 0.35, "pelo": "1a1412", "sonrisa": True})
    pelo(pj, "cola", "1a1412", {"pol_cola": 1.0, "gomita": "2a2a2a"})
    anteojos(pj, "2a2a3a")
    ambo = hexc("7cc4b8")
    torso(pj, ambo, ambo)
    gp = hexc("f8f8f6")
    prenda(pj, p.cadera_z - 0.02, p.hombro_z + 0.004, 0.014, gp, arco=(0.42, 2 * PI - 0.42), hem=(p.rodilla_z + 0.03, 0.035))
    solapas(pj, gp, p.pecho_z - 0.05, ancho=0.035)
    bolsillo(pj, -0.08, p.pecho_z - 0.02, 0.045, 0.05, osc(gp, 0.94), extra=0.026)
    # estetoscopio
    z = p.cuello_z - 0.01
    pts = []
    for i in range(9):
        a = lerp(-1.6, 1.6, i / 8)
        zz = z - 0.11 * (1 - abs(math.sin(a))) ** 0.5 * (abs(a) < 1.2) - 0.0
        e = torso_en(pj, zz)
        pts.append(Vector((math.sin(a) * (p.cuello_r * 1.4 + 0.012), e[2] + math.cos(a) * (e[4] * 0.6 + 0.03), zz)))
    for i in range(8):
        tubo(pj.m, pts[i], pts[i + 1], 0.0045, 0.0045, hexc("2a2a30"), "fijo", peso_torso(p), seg=6)
    e = torso_en(pj, p.pecho_z - 0.06)
    elipsoide(pj.m, (0.05, e[2] + e[4] + 0.03, p.pecho_z - 0.07), (0.015, 0.008, 0.015), hexc("c8c8d0"), "fijo", peso_torso(p), seg=10, aros=6)
    tubo(pj.m, (0.05, e[2] + e[4] + 0.03, p.pecho_z - 0.06), pts[6], 0.0045, 0.0045, hexc("2a2a30"), "fijo", peso_torso(p), seg=6)
    piernas(pj, ambo, zapato="zapatilla", col_zapato="f4f4f4")
    brazos(pj, gp, hexc(piel))
    return pj


PERSONAJES = {
    "dona_rosa": dona_rosa, "abuela": abuela, "jubilado": jubilado, "turista_gringo": turista_gringo, "mochilera": mochilera,
    "oficinista": oficinista, "oficinista_mujer": oficinista_mujer, "escolar": escolar, "escolar_nena": escolar_nena, "pibe": pibe,
    "mozo": mozo, "granadero": granadero, "bandoneonista": bandoneonista, "bailarina": bailarina, "hincha": hincha, "agente": agente,
    "barrendero": barrendero, "cocinero": cocinero, "almacenero": almacenero, "estudiante": estudiante, "artesano": artesano,
    "farmaceutica": farmaceutica,
}


# =====================================================================================  exportación
HUESOS = ["cadera", "torso", "cabeza", "brazo_i", "antebrazo_i", "brazo_d", "antebrazo_d", "muslo_i", "pierna_i", "muslo_d", "pierna_d"]


def limpiar():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials):
        for d in list(coll):
            coll.remove(d)


def a_blender(mm, nombre, arm_obj):
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    uv = bm.loops.layers.uv.new("zona")
    dl = bm.verts.layers.deform.verify()
    vs = [bm.verts.new(c) for c in mm.co]
    bm.verts.ensure_lookup_table()
    gi = {h: i for i, h in enumerate(HUESOS)}
    for v, w in zip(vs, mm.peso):
        tot = sum(w.values())
        for h, x in w.items():
            if x > 1e-4:
                v[dl][gi[h]] = x / tot
    vistos = set()
    for (idx, cols, zona, sv) in mm.caras:
        clave = tuple(sorted(idx))
        if clave in vistos:
            continue
        vistos.add(clave)
        try:
            f = bm.faces.new([vs[i] for i in idx])
        except ValueError:
            continue
        f.smooth = sv
        zi = ZONAS.get(zona, 0)
        for lp, c in zip(f.loops, cols):
            lp[col] = (c[0], c[1], c[2], 1.0)
            lp[uv].uv = ((zi + 0.5) / 8.0, 0.5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(nombre)
    bm.to_mesh(me)
    bm.free()
    if me.color_attributes:
        me.color_attributes.active_color = me.color_attributes["Col"]
        me.color_attributes.render_color_index = 0
    ob = bpy.data.objects.new(nombre, me)
    bpy.context.scene.collection.objects.link(ob)
    for h in HUESOS:
        ob.vertex_groups.new(name=h)
    ob.parent = arm_obj
    md = ob.modifiers.new("Esqueleto", "ARMATURE")
    md.object = arm_obj
    return ob


def esqueleto(pj):
    arm = bpy.data.armatures.new("Esqueleto")
    ao = bpy.data.objects.new("Esqueleto", arm)
    bpy.context.scene.collection.objects.link(ao)
    bpy.context.view_layer.objects.active = ao
    ao.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}
    for h in HUESOS:
        cab, punta, padre = pj.huesos[h]
        b = arm.edit_bones.new(h)
        b.head = cab
        b.tail = punta if (punta - cab).length > 0.01 else cab + Vector((0, 0, 0.05))
        b.roll = 0.0
        eb[h] = b
    for h in HUESOS:
        padre = pj.huesos[h][2]
        if padre:
            eb[h].parent = eb[padre]
            eb[h].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ao


def exportar(pj):
    limpiar()
    ao = esqueleto(pj)
    cu = a_blender(pj.m, "Cuerpo", ao)
    objs = [ao, cu]
    if pj.sombrero:
        so = a_blender(pj.sombrero, "Sombrero", ao)
        objs.append(so)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ao
    ruta = os.path.join(OUT, pj.nombre + ".glb")
    bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
                              export_materials="NONE", export_vertex_color="NAME", export_vertex_color_name="Col", export_all_vertex_colors=False,
                              export_cameras=False, export_lights=False, export_skins=True, export_animations=False,
                              export_texcoords=True, export_normals=True, export_def_bones=False)
    return ruta, objs


def info(pj):
    p = pj.p
    return {
        "alto": round(p.alto, 3),
        "cadera": round(p.cadera_z, 3),
        "rodilla": round(p.rodilla_z, 3),
        "cabeza": round(p.cab.z, 3),
        "cabeza_r": round(p.R.z, 3),
        "nino": p.nino,
        "sombrero": pj.tipo_sombrero,
        "color_sombrero": "#%02x%02x%02x" % tuple(int(c * 255) for c in pj.color_sombrero) if pj.sombrero else "",
        "zonas": {z: "#%02x%02x%02x" % tuple(int(round(c * 255)) for c in col) for z, col in pj.base.items() if z != "fijo"},
        "pose": pj.pose,
    }


# =====================================================================================  render de prueba
def material_vista():
    mat = bpy.data.materials.new("Vista")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    at = nt.nodes.new("ShaderNodeVertexColor")
    at.layer_name = "Col"
    gm = nt.nodes.new("ShaderNodeGamma")
    gm.inputs[1].default_value = 2.2
    nt.links.new(at.outputs[0], gm.inputs[0])
    nt.links.new(gm.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    return mat


if __name__ == "__main__":
    nombres = SOLO or list(PERSONAJES.keys())
    datos = {}
    ruta_json = os.path.join(OUT, "personas.json")
    if os.path.exists(ruta_json):
        with open(ruta_json, encoding="utf-8") as fh:
            datos = json.load(fh)
    for n in nombres:
        pj = construir(n)
        cruces = chequear_sombrero(pj)
        ruta, objs = exportar(pj)
        datos[n] = info(pj)
        tri = sum(len(c[0]) - 2 for c in pj.m.caras)
        print("OK %-18s %5d tris  sombrero=%-8s cruces=%d  %d KB" % (n, tri, pj.tipo_sombrero or "-", cruces, os.path.getsize(ruta) // 1024))
    with open(ruta_json, "w", encoding="utf-8") as fh:
        json.dump(datos, fh, indent=1, ensure_ascii=False, sort_keys=True)
