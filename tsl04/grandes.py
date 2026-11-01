# -*- coding: utf-8 -*-
"""Los dos niveles grandes de PULSO: Lasermania (5) y Runthedrun (6).

Se montan con piezas (calles, escaleras, balizas) en vez de listar a mano 150
bloques, y los lee disena_niveles.py igual que los otros cuatro: mismos bloques
en celdas de 16 px, mismos obstaculos y las mismas comprobaciones de alcance.

Lo que tienen de distinto de los cuatro primeros:
  * BALIZAS (escenas/obstaculos/Baliza.tscn): puntos de control que recargan la
    carga a tope. Un nivel de 500 celdas no cabe en los 62 s de una carga ni se
    puede repetir entero cada vez que se muere.
  * El portal esta al otro extremo, no junto a la aparicion: se va, no se va y
    se vuelve. La terminal esta antes del portal y la puerta justo delante.
"""

C = 16

import math

# El personaje que MAS vuela: TSL-02 (250 px/s y 125 px de salto) saltando tarde,
# con los 0,1 s de coyote. Todo lo que se pone "despues de aterrizar" (una baliza,
# unos pinchos) y el ancho de cada plataforma se mide contra el, no contra TSL-04:
# con las cuentas de TSL-04, TSL-02 se pasaba de una plataforma de 8 y caia al
# vacio, aterrizaba encima de unos pinchos y saltaba por encima de una baliza sin
# tocarla.
_VEL_MAX, _ALT_MAX, _COYOTE = 250.0, 125.0, 0.10


def aterrizaje(hueco, dy):
    """Hasta cuantas celdas despues del principio de la plataforma de llegada puede
    aterrizar el personaje que mas vuela, saltando a tope desde el borde de la
    anterior. dy > 0: la llegada esta mas abajo."""
    g = 980.0
    vs = math.sqrt(2 * g * _ALT_MAX)
    caida = _ALT_MAX + dy * C
    t = vs / g + math.sqrt(2 * max(caida, 0.0) / (g * 1.6))
    return (_VEL_MAX * (t + _COYOTE) - hueco * C) / C


def tras_aterrizar(hueco, dy, margen=2):
    """La primera celda donde ya ha aterrizado cualquiera."""
    return int(math.ceil(aterrizaje(hueco, dy))) + margen


class Nivel:
    def __init__(self, id, titulo, par, alto, anclaje):
        self.d = {"id": id, "titulo": titulo, "gdd": 0, "par": par, "paleta": "cian",
                  "ancho": 0, "alto": alto, "bloques": [], "exentas": [],
                  "trepadas": [], "fragmentos": [], "obstaculos": [], "balizas": [],
                  "anclaje": anclaje}

    # --- geometria
    def bloque(self, x, y, w, h):
        self.d["bloques"].append((x, y, w, h))
        self.d["ancho"] = max(self.d["ancho"], x + w)

    def montante(self, x, y, w=3, h=2):
        """Bloque que cuelga solo para sujetar un emisor: no es ruta."""
        self.bloque(x, y, w, h)
        self.d["exentas"].append((x, y))

    # --- obstaculos
    def laser(self, cx, fila_fin, largo, reposo=1.2, carga=0.5, disparo=0.8, desfase=0.0):
        """Cortina de `largo` celdas cuya ULTIMA fila es `fila_fin`. El emisor
        cuelga de un montante justo encima: el haz ocupa las filas
        emisor+1 .. emisor+largo (el emisor esta en fila_fin - largo)."""
        y_e = fila_fin - largo
        self.montante(cx - 1, y_e - 2)
        ex = ("largo_celdas = %d\nreposo = %g\ncarga = %g\ndisparo = %g\ndesfase = %g"
              % (largo, reposo, carga, disparo, desfase))
        self.d["obstaculos"].append(("laser", cx, y_e, ex))

    def cortina_suelo(self, cx, fila_suelo, largo=11, **kw):
        """Cortina sobre un suelo: el haz llega hasta la celda justo encima de el."""
        self.laser(cx, fila_suelo - 1, largo, **kw)

    def zapador(self, cx, y_montante):
        self.montante(cx - 1, y_montante)
        self.d["obstaculos"].append(("zapador", cx, y_montante + 2))

    def dron(self, x, y, recorrido=96):
        self.d["obstaculos"].append(("dron", x, y, "recorrido = Vector2(%d, 0)" % recorrido))

    def pinchos(self, x, fila_suelo):
        self.d["obstaculos"].append(("pinchos", x, fila_suelo - 1))

    def baliza(self, x, fila_suelo):
        self.d["balizas"].append((x, fila_suelo - 1))

    def fragmento(self, x, y):
        self.d["fragmentos"].append((x, y))

    # --- piezas
    def cadena(self, x_borde, y, pasos, w=10, hueco=7, dy=-4, lasers=(), params=None):
        """Plataformas una tras otra a partir del borde derecho (x_borde) de otra
        cuya superficie esta en la fila y. La k-esima va en x_borde + hueco +
        k*(w+hueco), en la fila y + (k+1)*dy. `lasers` son los huecos (0 = el
        primero) con una cortina que cruza el salto, y `params` sus tiempos.
        Devuelve el borde derecho y la fila de la ultima."""
        params = params or {}
        for k in range(pasos):
            self.bloque(x_borde + hueco + k * (w + hueco), y + (k + 1) * dy, w, 2)
        for k in lasers:
            y_ant, y_sig = y + k * dy, y + (k + 1) * dy
            cx = x_borde + k * (w + hueco) + hueco // 2
            # El salto cruza el hueco entre dos alturas. El emisor (y su montante,
            # que es solido) tiene que quedar POR ENCIMA de donde llega la cabeza:
            # un salto sube 115 px y el personaje mide 28, o sea 8,9 filas sobre la
            # superficie de salida (9,6 con los 125 px de TSL-02). Con 8 filas de
            # margen la cabeza topaba con el montante y el bot se caia al hueco.
            # La cortina baja hasta 2 filas por debajo de la superficie mas baja.
            alto = max(y_ant, y_sig) - min(y_ant, y_sig) + 13
            self.laser(cx, max(y_ant, y_sig) + 2, alto, **params.get(k, {}))
        return x_borde + pasos * (w + hueco), y + pasos * dy


def lasermania():
    N = Nivel("n5_lasermania", "Nivel 5  ·  Lasermania", 110.0, 100, (16, 89))
    d = N.d

    # --- tramo 1: la calle. Un suelo de 100 celdas con cuatro cortinas que
    # cruzan todo el pasillo y un fragmento flotando entre dos de ellas (a 6
    # filas del suelo: se coge saltando justo ahi, entre los haces)
    N.bloque(0, 90, 100, 3)
    for cx, des in ((34, 0.0), (50, 0.9), (66, 1.8), (82, 0.4)):
        N.cortina_suelo(cx, 90, desfase=des)
    N.fragmento(58, 84)

    # --- tramo 2: la escalera. Pasarela de la baliza y cuatro peldanos que suben
    # 4 filas cada uno, con una cortina en medio de dos de los saltos
    N.bloque(107, 90, 14, 2)
    N.baliza(107 + tras_aterrizar(7, 0), 90)
    x, y = N.cadena(121, 90, 4, lasers=(1, 3),
                    params={1: {"reposo": 1.6, "carga": 0.5, "disparo": 0.6, "desfase": 0.5},
                            3: {"reposo": 1.6, "carga": 0.5, "disparo": 0.6, "desfase": 1.4}})

    # --- tramo 3: la segunda calle, mas corta y con tiempos distintos en cada
    # cortina, para que no se pueda aprender un solo ritmo
    N.bloque(x + 7, y - 4, 74, 2)
    N.baliza(x + 7 + tras_aterrizar(7, -4), y - 4)
    fy = y - 4
    for cx, kw in ((x + 33, {"reposo": 1.0, "carga": 0.5, "disparo": 0.8, "desfase": 0.3}),
                   (x + 47, {"reposo": 1.4, "carga": 0.5, "disparo": 0.7, "desfase": 1.2}),
                   (x + 61, {"reposo": 0.9, "carga": 0.5, "disparo": 0.9, "desfase": 2.0}),
                   (x + 75, {"reposo": 1.3, "carga": 0.5, "disparo": 0.7, "desfase": 0.8})):
        N.cortina_suelo(cx, fy, **kw)
    N.fragmento(x + 40, fy - 6)
    xb = x + 7 + 74

    # --- tramo 4: otra escalera, con cortinas en dos de los saltos
    N.bloque(xb + 7, fy, 14, 2)
    N.baliza(xb + 7 + tras_aterrizar(7, 0), fy)
    x2, y2 = N.cadena(xb + 21, fy, 4, lasers=(1, 2),
                      params={1: {"reposo": 1.5, "carga": 0.5, "disparo": 0.7, "desfase": 0.0},
                              2: {"reposo": 1.5, "carga": 0.5, "disparo": 0.7, "desfase": 1.1}})
    # Sin torretas. Habia dos sobre los peldanos: una alcanzaba el sitio donde se
    # espera a la cortina del segundo hueco (esperar te mataba la torreta, y no
    # esperar, el laser), y la otra dispara medio segundo despues de que entras en
    # su alcance, asi que cruzar su peldano pedia cebarla y esperar al disparo,
    # algo que nada en el nivel ensena. Lasermania va de lasers.

    # --- tramo 5: el descenso. Peldanos que bajan 9 filas con 10 de hueco (y 10 de
    # ancho: con menos, un personaje que vuele mas lejos se pasaria de largo), y
    # una cortina en los dos ultimos saltos
    N.bloque(x2 + 7, y2, 14, 2)
    N.baliza(x2 + 7 + tras_aterrizar(7, 0), y2)
    x3, y3 = N.cadena(x2 + 21, y2, 4, w=10, hueco=10, dy=9, lasers=(2, 3),
                      params={2: {"reposo": 1.6, "carga": 0.5, "disparo": 0.6, "desfase": 0.0},
                              3: {"reposo": 1.6, "carga": 0.5, "disparo": 0.6, "desfase": 1.0}})

    N.fragmento(x2 + 21 + 10 + 5, y2 + 9 - 5)       # sobre el primer peldano del descenso

    # --- tramo 6: el final. Baliza, dos cortinas, y la terminal en una repisa
    # SOBRE el pasillo (hay que subir a ella y volver a bajar); la puerta y el
    # portal al fondo. La terminal esta en la ruta pero no se activa corriendo:
    # hay que pararse 0,45 s encima, y es toma de tierra.
    N.bloque(x3 + 7, y3, 78, 3)
    N.baliza(x3 + 7 + tras_aterrizar(7, 0), y3)
    N.cortina_suelo(x3 + 30, y3, desfase=0.6)
    N.cortina_suelo(x3 + 43, y3, desfase=1.5, reposo=1.4, carga=0.5, disparo=0.7)
    N.bloque(x3 + 52, y3 - 6, 12, 2)
    d["interruptor"] = (x3 + 57, y3 - 7)
    d["puerta"] = (x3 + 72, y3 - 3)
    d["portal"] = (x3 + 76, y3 - 2)
    d["fin_x"] = x3 + 7 + 78
    return d


# ------------------------------------------------------------ alcance (como en
# disena_niveles.py: mismas constantes que Jugador.tscn y el mismo margen)
import math
_G, _ALT, _VEL, _MARGEN = 980.0, 115.0, 220.0, 56.0
_VS = math.sqrt(2 * _G * _ALT)


def hueco_max(dy):
    """El hueco mas ancho (en celdas) que se salva yendo a una superficie dy filas
    mas abajo (dy > 0) o mas arriba (dy < 0)."""
    if dy < 0:
        h = -dy * C
        r = _VEL * (_VS + math.sqrt(max(_VS * _VS - 2 * _G * h, 0.0))) / _G
        return int((r - _MARGEN) // C)
    t_baj = math.sqrt(2 * dy * C / (_G * 1.6))
    return int(_VEL * (_VS / _G + t_baj + 0.30) // C)


def runthedrun():
    """Un nivel para CORRER: una ruta larga de plataformas que se recorre en un
    sentido y sin pararse, con drones de purga colgando sobre ella. Un dron que te
    ve te persigue para siempre, mas despacio que tu corriendo (118 contra 220
    px/s): quien corre se los va dejando atras, y quien duda los junta detras.
    Por eso no hay nada que obligue a volver ni a esperar, salvo la terminal."""
    import random
    rng = random.Random(6)
    N = Nivel("n6_runthedrun", "Nivel 6  \u00b7  Runthedrun", 75.0, 80, (16, 65))
    d = N.d
    # la salida: una pasarela larga y un dron colgando encima que te ve en cuanto
    # echas a andar y sale detras de ti: se empieza corriendo
    N.bloque(0, 66, 34, 3)
    N.dron(24, 55, recorrido=96)
    x, y = 34, 66                 # borde derecho y fila de la ultima plataforma
    n = 0
    baliza_en = (92, 190, 292, 380)   # la primera plataforma que pase de estas x
    puestas = 0
    ultimo_dron = 24
    while x < 405:
        # un peldano: hueco, desnivel y ancho
        dy = rng.choice([0, 0, 0, -2, -2, -3, -4, 2, 3, 4])
        if y + dy < 40 or y + dy > 70:
            dy = 0
        hueco = rng.randint(5, max(5, min(hueco_max(dy) - 1, 9)))
        pad = puestas < len(baliza_en) and x + hueco > baliza_en[puestas]
        w = 16 if pad else rng.choice([8, 10, 11, 12, 14, 26, 26])
        # que quepa el aterrizaje mas largo, con sitio para volver a saltar
        llega = tras_aterrizar(hueco, dy)
        w = max(w, llega + 2)
        if pad:
            w = max(w, llega + 4)
        xs, ys = x + hueco, y + dy
        N.bloque(xs, ys, w, 2)
        if pad:
            N.baliza(xs + llega, ys)
            puestas += 1
        else:
            # Pinchos en las plataformas largas (26), a 13 celdas del principio: hay
            # que saltarlos. Un salto aterriza 6-8 celdas pasado el hueco y vuela 12,
            # asi que mas cerca del principio se aterriza encima de ellos, y en una
            # plataforma corta el salto que los esquiva acaba pasado el borde.
            # (y con el aterrizaje de TSL-02: nunca antes de donde ella cae + 3)
            pos = max(13, llega + 3)
            if w >= 26 and w >= pos + 12 and xs - ultimo_dron > 6:
                N.pinchos(xs + pos, ys)
            # Un dron cada 40 celdas mas o menos, a 11 filas del suelo: por encima de
            # donde llega la cabeza en un salto (8,9 filas; a 6, cada salto que se
            # diera debajo chocaba con el). Te ve al pasar por debajo (176 px, ve a
            # 190), baja a por ti y se queda detras persiguiendote.
            if xs - ultimo_dron >= 36 and w >= 10:
                N.dron(xs + 3, ys - 11, recorrido=rng.choice([64, 96, 128]))
                ultimo_dron = xs
        x, y = xs + w, ys
        n += 1
    # Ningun dron que patrulle a menos de 13 celdas (208 px, ve a 190) de una
    # baliza: te veria nada mas reaparecer.
    xs_bal = [bx for bx, by in d["balizas"]]
    quedan = []
    for o in d["obstaculos"]:
        if o[0] == "dron" and o[1] > 30:
            rec = int(o[3].split("(")[1].split(",")[0]) // C
            if any(o[1] - 13 <= bx <= o[1] + rec + 13 for bx in xs_bal):
                continue
        quedan.append(o)
    d["obstaculos"] = quedan
    # tres fragmentos a 5 filas sobre otras tantas plataformas, a un tercio, a dos
    # tercios y al final de la ruta: se cogen con un salto sin parar
    anchas = [b for b in d["bloques"] if b[2] >= 12 and b[1] >= 40]
    for k in (len(anchas) // 4, len(anchas) // 2, (3 * len(anchas)) // 4):
        bx, by, bw, bh = anchas[k]
        N.fragmento(bx + bw // 2, by - 5)
    # --- el final: respiro sin drones, la terminal, la puerta y el portal
    N.bloque(x + 7, y, 90, 3)
    d["interruptor"] = (x + 7 + 40, y - 1)
    d["puerta"] = (x + 7 + 66, y - 3)
    d["portal"] = (x + 7 + 70, y - 2)
    # y tres drones al fondo, que se despiertan al pasar: el ultimo tramo a la
    # carrera, ya con la puerta abierta
    for dx in (56, 66, 78):
        N.dron(x + 7 + dx, y - 11, recorrido=64)
    return d
