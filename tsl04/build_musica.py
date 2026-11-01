# -*- coding: utf-8 -*-
"""Musica ambiental de PULSO, sintetizada.

    python3 build_musica.py

Mismo mundo sonoro que los efectos: el juego pasa DENTRO de una computadora,
asi que ondas cuadradas, sierras y ruido digital. Nada organico, ningun
instrumento que exista.

Tres reglas que mandan sobre el gusto:

1. EL AUDIO REFUERZA, NUNCA INFORMA. Viene de build_sonido.py y aqui pesa
   doble: la musica no puede tapar los efectos, que son los que si dicen algo.
   Por eso va a un bus propio, mezclada muy por debajo, y sin nada agudo que
   compita con el aviso de peligro (1046 Hz) ni con el fragmento.

2. EN PULSO PARARSE MATA. La musica no puede invitar a quedarse quieto:
   lleva un pulso constante de negra, que es de donde sale el nombre del juego.
   No hay silencios largos ni respiraciones: el juego no te las da.

3. EL BUCLE TIENE QUE CERRAR SIN CHASQUIDO. El juego pone loop_begin = 0 y
   loop_end = el final del archivo, asi que la onda salta del ultimo sample al
   primero. Si una voz sostenida llega al final a mitad de ciclo, se oye un
   clic en cada vuelta, cada 64 s, para siempre. Se resuelve por
   construccion, no a base de fundidos: las voces con notas llevan envolvente
   que acaba en cero, y las voces SOSTENIDAS se afinan a un multiplo exacto de
   1/DURACION con cierra(), asi que completan un numero entero de ciclos.
"""
import math, os, struct, wave

# 22050 y no 44100: son ondas cuadradas y sierras con casi todo por debajo de
# 4 kHz. A 44100 los 64 s pesarian 5,4 MB en vez de 2,7 para el mismo sonido,
# y el juego va a Play Store, donde cada megabyte cuenta en la descarga.
SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "musica")
os.makedirs(OUT, exist_ok=True)

BPM = 150.0                  # negra = 0,40 s
NEGRA = 60.0 / BPM
COMPAS = NEGRA * 4
# 40 compases = 64,00 s. Con 16 (25,6 s) el bucle daba 140 vueltas en una hora
# de juego y se hacia insoportable. La duracion no sale gratis, asi que el
# archivo se importa COMPRIMIDO en Godot: en disco pesa 2,7 MB pero en el
# paquete que se sube a Play Store va a un cuarto de eso.
COMPASES = 40
DUR = COMPAS * COMPASES      # 64,00 s
N = int(round(DUR * SR))     # 1.411.200 muestras clavadas
F0 = 1.0 / DUR               # 0,015625 Hz: la fundamental del bucle


def cierra(f):
    """Afina f al multiplo mas cercano de F0.

    Una voz sostenida solo empalma consigo misma si completa un numero ENTERO
    de ciclos en el bucle. Desafinar 0,02 Hz es inaudible; el clic de no
    hacerlo se oye en cada vuelta.
    """
    return max(F0, round(f / F0) * F0)


# ---------------------------------------------------------------- osciladores
def cuadrada(f, t, ciclo=0.5):
    return 1.0 if (f * t) % 1.0 < ciclo else -1.0


def sierra(f, t):
    return 2.0 * ((f * t) % 1.0) - 1.0


_semilla = [987654321]


def ruido():
    # congruencial propio, igual que en build_sonido.py: asi el archivo sale
    # identico en cualquier maquina y el arte es reproducible
    _semilla[0] = (_semilla[0] * 1103515245 + 12345) & 0x7FFFFFFF
    return _semilla[0] / 1073741823.5 - 1.0


def campana(q, filo=0.5):
    """Envolvente de nota: sube rapido y cae a CERO exacto en q = 1."""
    if q <= 0.0 or q >= 1.0:
        return 0.0
    a = min(1.0, q / 0.02)
    return a * (1.0 - q) ** filo


# ------------------------------------------------------------------- armonia
# La menor. El bajo recorre Am - F - C - G, cuatro compases cada uno: es la
# vuelta mas transitada que hay, y aqui eso es una virtud, porque la musica
# tiene que desaparecer detras del juego, no que se te quede pegada.
LA = 55.0
RAICES = [LA * 2, LA * 2 * 2 ** (-4 / 12.0), LA * 2 * 2 ** (3 / 12.0),
          LA * 2 * 2 ** (-2 / 12.0)]          # A2, F2, C3, G2
# pentatonica menor de la, dos octavas, para el arpegio del bus de datos
ESCALA = [0, 3, 5, 7, 10]


def nota(semis, octava=0):
    return LA * 4 * 2 ** ((semis + 12 * octava) / 12.0)


# --------------------------------------------------------------------- voces
# Las capas no suenan todas todo el rato: el tema se abre y se cierra por
# secciones para que 64 s no sean el mismo compas cuarenta veces. Cada tramo
# dice que compases toca. El ultimo vuelve a quedarse desnudo, que es lo que
# hace que el salto al compas 0 se oiga como que sigue y no como que empieza.
def suena(compas, desde, hasta):
    return desde <= compas < hasta


def pulso():
    """El latido. Negra, cuadrada grave, corta. Es el metronomo del juego."""
    v = [0.0] * N
    for k in range(COMPASES * 4):
        f = RAICES[(k // 16) % 4]
        ini = int(round(k * NEGRA * SR))
        largo = int(NEGRA * 0.55 * SR)
        for i in range(largo):
            j = ini + i
            if j >= N:
                break
            q = i / largo
            t = i / SR
            # el ciclo se estrecha al caer: el timbre se afila, como un
            # condensador descargandose
            v[j] += cuadrada(f, t, 0.5 - 0.18 * q) * campana(q, 1.6) * 0.42
    return v


def bus():
    """Arpegio de semicorcheas: los paquetes de datos del fondo, en sonido."""
    v = [0.0] * N
    paso = NEGRA / 4.0
    total = COMPASES * 16
    for k in range(total):
        compas = k // 16
        # el arpegio entra en el compas 8 y se retira en el 32: es la capa que
        # marca las dos mitades del tema
        if not suena(compas, 8, 32):
            continue
        grado = ESCALA[k % 5]
        # a partir del compas 20 sube una octava: misma melodia, mas tension
        octava = (1 if compas < 20 else 2) + ((k // 5) % 2)
        f = nota(grado, octava)
        ini = int(round(k * paso * SR))
        largo = int(paso * 0.9 * SR)
        # respira cada dos compases: una semicorchea de cada 32 se calla, y
        # ese hueco es lo unico que impide que el arpegio se vuelva un zumbido
        if k % 32 == 31:
            continue
        for i in range(largo):
            j = ini + i
            if j >= N:
                break
            q = i / largo
            t = i / SR
            v[j] += cuadrada(f, t, 0.22) * campana(q, 2.2) * 0.13
    return v


def zumbido():
    """El ronroneo de la maquina. Sostenido, asi que va afinado con cierra()."""
    v = [0.0] * N
    for b in range(COMPASES // 4):
        raiz = RAICES[b % 4]
        # dos sierras separadas 0,7 Hz: el batido lento es lo que hace que
        # suene a aparato encendido y no a nota de teclado
        f1 = cierra(raiz)
        f2 = cierra(raiz + 0.7)
        f3 = cierra(raiz * 2)
        ini = int(round(b * 4 * COMPAS * SR))
        fin = int(round((b + 1) * 4 * COMPAS * SR))
        if fin > N:
            fin = N
        largo = fin - ini
        for i in range(largo):
            j = ini + i
            if j >= N:
                break
            t = j / SR                    # tiempo ABSOLUTO: la fase de una voz
            q = i / largo                 # sostenida se mide desde el origen
            # entra y sale en cruces suaves para que el cambio de acorde no
            # chasquee; en los extremos del bucle la fase ya cierra sola
            g = min(1.0, q / 0.06) * min(1.0, (1.0 - q) / 0.06)
            v[j] += (sierra(f1, t) + sierra(f2, t)) * 0.055 * g
            v[j] += sierra(f3, t) * 0.022 * g
    return v


def reloj():
    """Tic de ruido en la contra. Marca el medio tiempo sin ocupar sitio."""
    v = [0.0] * N
    for k in range(COMPASES * 4):
        # el reloj solo marca el tramo central: es lo que hace que la vuelta
        # al compas 0 se note como un respiro y no como un corte
        if not suena(k // 4, 12, 34):
            continue
        ini = int(round((k + 0.5) * NEGRA * SR))
        largo = int(0.018 * SR)
        fuerte = (k % 4) == 2
        for i in range(largo):
            j = ini + i
            if j >= N:
                break
            q = i / largo
            v[j] += ruido() * campana(q, 3.0) * (0.075 if fuerte else 0.038)
    return v


def barrido_lento():
    """Un barrido que cruza los 16 compases: da sensacion de avance sin marcar
    ningun sitio concreto. Cierra porque empieza y acaba en silencio."""
    v = [0.0] * N
    for j in range(N):
        q = j / N
        t = j / SR
        f = cierra(180.0 + 90.0 * math.sin(2.0 * math.pi * q))
        # sube y baja una vez por vuelta, y el volumen se apaga en los bordes
        g = math.sin(math.pi * q) ** 2
        v[j] += sierra(f, t) * 0.028 * g
    return v


# --------------------------------------------------------------------- mezcla
def circuito():
    capas = [pulso(), bus(), zumbido(), reloj(), barrido_lento()]
    v = [0.0] * N
    for c in capas:
        for j in range(N):
            v[j] += c[j]
    return v


def guardar(nombre, muestras, vol=0.58):
    """vol por debajo de los efectos (0,72): la musica va detras, siempre."""
    pico = max(1e-6, max(abs(x) for x in muestras))
    k = vol / pico
    datos = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x * k)) * 32767))
                     for x in muestras)
    ruta = os.path.join(OUT, nombre + ".wav")
    with wave.open(ruta, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(datos)
    salto = abs(muestras[0] - muestras[-1]) * k
    print("  %-12s %5.2f s  %d muestras  %.0f KB" %
          (nombre, len(muestras) / SR, len(muestras), len(datos) / 1024))
    print("  empalme del bucle: salto de %.5f (0 = sin chasquido)" % salto)


# ================================================================== LIBRE
# El tema del final. Todo lo de arriba es de "circuito" y NO se toca: este bloque
# lleva sus propias constantes, y ademas no usa ruido(), cuyo estado es global.
# Asi "circuito" sale identico byte a byte, y se comprueba.
#
# Lo que cuenta con la musica:
#  - DO MAYOR, la relativa de LA MENOR: son exactamente las mismas notas que
#    "circuito", pero ahora resuelven hacia arriba. Es el mismo mundo en paz.
#  - 100 BPM y el latido UNA vez por compas, no en cada negra. En el juego el
#    pulso constante dice "no pares"; aqui ya puede parar, y el pulso respira.
#  - Ni tic de reloj ni arpegio de datos: se acabo la prisa.
#  - La melodia se queda por debajo de los 1046 Hz del aviso de peligro, como
#    toda la musica del juego, aunque aqui no haya peligros: es la misma regla.

L_BPM = 100.0                  # negra = 0,60 s
L_NEGRA = 60.0 / L_BPM
L_COMPAS = L_NEGRA * 4
L_COMPASES = 16                # 38,40 s: cubre el final entero sin dar la vuelta
L_DUR = L_COMPAS * L_COMPASES
L_N = int(round(L_DUR * SR))   # 846.720 muestras
L_F0 = 1.0 / L_DUR

def l_cierra(f):
    """Lo mismo que cierra(), con la fundamental de ESTE bucle."""
    return max(L_F0, round(f / L_F0) * L_F0)

def triangulo(f, t):
    # mas suave que la sierra: es la misma familia de ondas, con menos aristas
    return 2.0 * abs(sierra(f, t)) - 1.0

DO = 130.81
L_RAICES = [DO, DO * 2 ** (-3 / 12.0), DO * 2 ** (-7 / 12.0), DO * 2 ** (-5 / 12.0)]   # C3 A2 F2 G2
# pentatonica mayor de do (do re mi sol la), la misma escala de "circuito"
# empezando en otra nota
L_ESCALA = [0, 2, 4, 7, 9]
# la frase de la caja de musica, en grados de la escala; None es silencio
L_FRASE = [2, None, 3, 4, 3, None, 2, 1, 0, None, 1, 2, None, None, None, None]

def l_aire():
    """El colchon: dos triangulos, raiz y quinta, afinados para cerrar el bucle."""
    v = [0.0] * L_N
    for b in range(L_COMPASES // 4):
        raiz = L_RAICES[b % 4]
        f1 = l_cierra(raiz)
        f2 = l_cierra(raiz * 1.5 + 0.4)          # quinta, con un batido lentisimo
        ini = int(round(b * 4 * L_COMPAS * SR))
        fin = min(int(round((b + 1) * 4 * L_COMPAS * SR)), L_N)
        largo = fin - ini
        for i in range(largo):
            j = ini + i
            t = j / SR
            q = i / largo
            g = min(1.0, q / 0.10) * min(1.0, (1.0 - q) / 0.10)
            v[j] += (triangulo(f1, t) * 0.10 + triangulo(f2, t) * 0.06) * g
    return v

def l_latido():
    """El pulso del juego, pero una vez por compas y en triangulo: respira."""
    v = [0.0] * L_N
    for c in range(L_COMPASES):
        f = L_RAICES[(c // 4) % 4] * 0.5
        ini = int(round(c * L_COMPAS * SR))
        largo = int(L_NEGRA * 0.9 * SR)
        for i in range(largo):
            j = ini + i
            if j >= L_N:
                break
            q = i / largo
            v[j] += triangulo(f, i / SR) * campana(q, 2.0) * 0.30
    return v

def l_caja():
    """Caja de musica: la frase en negras, de la segunda a la penultima vuelta."""
    v = [0.0] * L_N
    for c in range(L_COMPASES):
        # entra en el compas 2 y calla en el 14: la vuelta al compas 0 queda con
        # solo el colchon y el latido, que es lo que hace que empalme sin costura
        if not suena(c, 2, 14):
            continue
        octava = 2                      # de do5 a la5: por debajo del aviso de 1046 Hz
        for k in range(4):
            grado = L_FRASE[(c * 4 + k) % len(L_FRASE)]
            if grado is None:
                continue
            f = DO * 2 ** ((L_ESCALA[grado] + 12 * octava) / 12.0)
            ini = int(round((c * 4 + k) * L_NEGRA * SR))
            largo = int(L_NEGRA * 1.6 * SR)       # suena mas que su negra: campana
            for i in range(largo):
                j = ini + i
                if j >= L_N:
                    break
                q = i / largo
                v[j] += triangulo(f, i / SR) * campana(q, 3.2) * 0.12
    return v

def libre():
    print("  libre: %d compases a %.0f BPM = %.2f s" % (L_COMPASES, L_BPM, L_DUR))
    capas = [l_aire(), l_latido(), l_caja()]
    v = [0.0] * L_N
    for c in capas:
        for j in range(L_N):
            v[j] += c[j]
    return v


# circuito PRIMERO: ruido() tiene estado global y cualquier tema generado antes
# le cambiaria el ruido.
TEMAS = [("circuito", circuito), ("libre", libre)]

if __name__ == "__main__":
    print("sintetizando musica en %s" % OUT)
    print("  %d compases a %.0f BPM = %.2f s  (%d muestras a %d Hz)"
          % (COMPASES, BPM, DUR, N, SR))
    for nombre, fn in TEMAS:
        guardar(nombre, fn())
    print("LISTO: %d tema(s)" % len(TEMAS))
