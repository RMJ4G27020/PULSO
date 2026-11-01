# -*- coding: utf-8 -*-
"""Generador de rayos segun el modelo de ruptura dielectrica (DBM).

Lo que dice la literatura y aqui se copia:

  * Mas del 50% de los pasos de un lider escalonado avanzan dentro de +-30
    grados de la direccion que llevaba. Ojo al matiz: eso quiere decir que
    casi la mitad se salen. Con sigma 32 y cola 0.18 sale el 55%, que da
    quiebres visibles; con sigma 17 salia el 86% y el rayo parecia humo.
  * La probabilidad de crecer en un sitio va como el potencial elevado a eta.
    Eta alto = rayo recto y con pocas ramas; eta bajo = mata muy ramificada.
  * La dimension fractal medida en descargas simuladas es 1.56 en aire y
    1.68 en superficie. MEDIDO AQUI: a escala de sprite esa cifra no se
    alcanza. Con 296 ramas se llega a 1.39 y con 5-8 ramas (lo que cabe en
    una celda de 64 px) sale ~1.05. La razon es que 1.56 se mide sobre
    descargas reales a lo largo de muchas decadas de escala, y un sprite
    tiene una decada y media. Asi que no se persigue el numero: se copian
    los rasgos que si se ven a este tamano (paso de +-30, ramas a 20-45,
    afilado hacia la punta).
  * Las ramas son mas cortas y mas finas que el tronco, y se abren
    tipicamente entre 20 y 45 grados.

Se usa sin Blender: devuelve listas de puntos y radios, y sabe medirse.
"""
import math, random

GRADO = math.pi / 180.0


def _giro(rnd, sigma, cola):
    """Angulo de giro de un paso. Nucleo gaussiano estrecho (el temblor) mas
    una cola pesada rara (el quiebre brusco). Ajustado para que mas de la
    mitad de los pasos caigan dentro de +-30 grados."""
    if rnd.random() < cola:
        return rnd.choice((-1.0, 1.0)) * rnd.uniform(35.0, 70.0) * GRADO
    return rnd.gauss(0.0, sigma * GRADO)


def camino(x, y, ang, largo, pasos, rnd, sigma=32.0, cola=0.18, deriva=0.0,
           tension=0.38):
    """Un tramo quebrado: devuelve [(x, y), ...].

    `tension` es lo que en el modelo hace el campo electrico: tira del canal
    hacia el electrodo. Sin ella el paseo aleatorio deriva y el rayo se
    enrosca sobre si mismo; con ella los quiebres siguen siendo grandes pero
    el conjunto avanza recto, que es como se ve un rayo de verdad."""
    paso = largo / pasos
    objetivo = ang
    pts = [(x, y)]
    for i in range(pasos):
        ang += _giro(rnd, sigma, cola) + deriva
        ang += (objetivo - ang) * tension
        x += math.cos(ang) * paso
        y += math.sin(ang) * paso
        pts.append((x, y))
    return pts, ang


def rayo(x0, y0, ang0, largo, rnd, pasos=9, nivel=0, max_nivel=2,
         p_rama=0.34, sigma=32.0, radio=1.0, tension=0.38):
    """Arbol completo. Devuelve [(puntos, radio, nivel), ...].

    Cada rama sale entre 20 y 45 grados del tronco, mide entre el 35% y el
    60% de lo que le queda al padre, y es bastante mas fina: asi se ve de un
    vistazo cual es el canal principal, que es lo que pasa de verdad."""
    ramas = []
    pts, _ = camino(x0, y0, ang0, largo, pasos, rnd, sigma=sigma, tension=tension)
    ramas.append((pts, radio, nivel))
    if nivel >= max_nivel:
        return ramas
    for i in range(1, pasos):
        if rnd.random() >= p_rama:
            continue
        bx, by = pts[i]
        # direccion que llevaba el tronco en ese punto
        ax, ay = pts[i - 1]
        base = math.atan2(by - ay, bx - ax)
        lado = rnd.choice((-1.0, 1.0))
        ang = base + lado * rnd.uniform(20.0, 45.0) * GRADO
        resto = largo * (1.0 - i / float(pasos))
        ramas += rayo(bx, by, ang, resto * rnd.uniform(0.35, 0.60), rnd,
                      pasos=max(3, pasos - 3), nivel=nivel + 1,
                      max_nivel=max_nivel, p_rama=p_rama * 0.7,
                      sigma=sigma * 1.25, radio=radio * 0.55, tension=tension)
    return ramas


# --------------------------------------------------------------- medicion
def dimension(ramas, cajas=(64, 48, 32, 24, 16, 12, 8)):
    """Dimension fractal por conteo de cajas. Rasteriza el arbol a varias
    resoluciones y ajusta log N(e) contra log(1/e)."""
    xs = [p[0] for r in ramas for p in r[0]]
    ys = [p[1] for r in ramas for p in r[0]]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    lado = max(x1 - x0, y1 - y0) or 1e-9
    ptos = []
    for pts, _, _ in ramas:
        for a, b in zip(pts, pts[1:]):
            n = max(2, int(200 * math.hypot(b[0] - a[0], b[1] - a[1]) / lado))
            for k in range(n + 1):
                t = k / float(n)
                ptos.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    xl, yl = [], []
    for n in cajas:
        e = lado / n
        ocupadas = {(int((px - x0) / e), int((py - y0) / e)) for px, py in ptos}
        xl.append(math.log(1.0 / e)); yl.append(math.log(len(ocupadas)))
    mx = sum(xl) / len(xl); my = sum(yl) / len(yl)
    num = sum((a - mx) * (b - my) for a, b in zip(xl, yl))
    den = sum((a - mx) ** 2 for a in xl) or 1e-9
    return num / den


def dentro_de_30(rnd, n=4000, sigma=32.0, cola=0.18):
    """Fraccion de pasos que avanzan dentro de +-30 grados. La literatura
    dice que en rayos reales pasa mas de la mitad de las veces."""
    d = sum(1 for _ in range(n) if abs(_giro(rnd, sigma, cola)) <= 30 * GRADO)
    return d / float(n)


# ------------------------------------------------------- puente con Blender
def a_curva(bpy, nombre, ramas, material, grosor, punta=0.45, y=0.0):
    """Una curva con una spline por rama. El radio baja hacia la punta:
    los canales se afilan segun se agota la carga."""
    cu = bpy.data.curves.new(nombre, 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = grosor
    cu.resolution_u = 1
    cu.bevel_resolution = 2
    cu.use_fill_caps = True
    for pts, radio, _ in ramas:
        sp = cu.splines.new('POLY')
        sp.points.add(len(pts) - 1)
        for i, (px, py) in enumerate(pts):
            t = i / float(len(pts) - 1)
            sp.points[i].co = (px, 0.0, py, 1.0)
            sp.points[i].radius = radio * (1.0 - (1.0 - punta) * t)
    o = bpy.data.objects.new(nombre, cu)
    o.data.materials.append(material)
    # las capas son tubos concentricos y opacos: si no se separan en
    # profundidad, la mas ancha tapa a las de dentro y solo se ve el halo
    o.location.y = y
    bpy.context.collection.objects.link(o)
    return o


def nucleo_y_halo(bpy, nombre, ramas, mat_nucleo, mat_halo, grosor, halo=3.2,
                  sep=0.05):
    """Dos pasadas: un halo ancho y apagado detras, y un nucleo fino y
    brillante delante. Hace falta porque el bloom de EEVEE NO se guarda en
    el PNG con fondo transparente: el resplandor tiene que ser geometria.
    La camara mira hacia +Y, asi que menos Y es mas cerca."""
    h = a_curva(bpy, nombre + "_halo", ramas, mat_halo, grosor * halo, y=sep)
    n = a_curva(bpy, nombre, ramas, mat_nucleo, grosor, y=-sep)
    return n, h


if __name__ == "__main__":
    rnd = random.Random(7)
    print("pasos dentro de +-30 grados: %.0f%%   (la literatura: >50%%)"
          % (100 * dentro_de_30(rnd)))
    print()
    print("%-8s %-8s %s" % ("p_rama", "ramas", "dimension fractal"))
    for p in (0.0, 0.15, 0.25, 0.34, 0.45, 0.60):
        ds, ns = [], []
        for s in range(24):
            r = random.Random(s * 13 + 1)
            arb = rayo(0.0, 0.0, math.radians(90), 1.0, r, p_rama=p)
            ds.append(dimension(arb)); ns.append(len(arb))
        d = sum(ds) / len(ds)
        print("%-8.2f %-8.1f %.3f %s" % (p, sum(ns) / len(ns), d,
              "  <-- lo que se usa en la estela" if abs(p - 0.30) < 0.03 else ""))
    print()
    print("1.56 es inalcanzable a este tamano: ver la nota de arriba.")
