# -*- coding: utf-8 -*-
"""Efectos de sonido de PULSO, sintetizados.

    python3 build_sonido.py

El juego pasa dentro de una computadora, asi que nada de sonidos organicos:
ondas cuadradas, barridos y ruido digital. Y una regla de diseno que viene
del propio juego: el audio REFUERZA, nunca informa de algo que no se vea.
Mucha gente juega en silencio, y los peligros ya avisan con luz y movimiento.
"""
import math, os, struct, wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sonidos")
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- osciladores
def cuadrada(f, t, ciclo=0.5):
    return 1.0 if (f * t) % 1.0 < ciclo else -1.0

def sierra(f, t):
    return 2.0 * ((f * t) % 1.0) - 1.0

_semilla = [12345]
def ruido():
    # congruencial propio: asi el resultado es identico en cualquier maquina
    _semilla[0] = (_semilla[0] * 1103515245 + 12345) & 0x7FFFFFFF
    return _semilla[0] / 1073741823.5 - 1.0

# ------------------------------------------------------------------- envolvente
def env(i, n, ataque=0.01, caida=0.0, sostenido=1.0, suelta=0.3):
    t = i / SR
    dur = n / SR
    if t < ataque:
        return t / ataque
    t2 = t - ataque
    if caida > 0 and t2 < caida:
        return 1.0 + (sostenido - 1.0) * (t2 / caida)
    resto = dur - ataque - caida
    if resto <= 0:
        return sostenido
    q = (t - ataque - caida) / resto
    return sostenido * max(0.0, 1.0 - q) ** (1.0 / max(suelta, 0.01))

def barrido(f0, f1, q, curva=1.0):
    return f0 + (f1 - f0) * (q ** curva)

# ---------------------------------------------------------------------- guardar
def guardar(nombre, muestras, vol=0.72):
    pico = max(1e-6, max(abs(v) for v in muestras))
    k = vol / pico                      # normaliza: ningun efecto satura
    datos = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v * k)) * 32767))
                     for v in muestras)
    ruta = os.path.join(OUT, nombre + ".wav")
    with wave.open(ruta, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(datos)
    print("  %-12s %5.2f s  %6d muestras" % (nombre, len(muestras) / SR, len(muestras)))

# ============================================================== los efectos
def salto(dur=0.16):
    n = int(SR * dur); out = []
    for i in range(n):
        q = i / n; t = i / SR
        f = barrido(330, 720, q, 0.55)          # sube: el cuerpo despega
        out.append(cuadrada(f, t, 0.42) * env(i, n, 0.004, 0.0, 1.0, 0.45) * 0.5)
    return out

def aterrizaje(dur=0.13):
    n = int(SR * dur); out = []
    for i in range(n):
        q = i / n; t = i / SR
        f = barrido(240, 90, q, 0.7)            # baja: el peso llega al suelo
        cuerpo = cuadrada(f, t, 0.5) * 0.55
        golpe = ruido() * 0.45 * (1.0 - q) ** 3
        out.append((cuerpo + golpe) * env(i, n, 0.002, 0.0, 1.0, 0.30))
    return out

def impulso(dur=0.22):
    n = int(SR * dur); out = []
    for i in range(n):
        q = i / n; t = i / SR
        f = barrido(880, 180, q, 1.6)
        out.append((sierra(f, t) * 0.6 + ruido() * 0.25) * env(i, n, 0.003, 0.0, 1.0, 0.5))
    return out

def muerte(dur=0.55):
    n = int(SR * dur); out = []
    for i in range(n):
        q = i / n; t = i / SR
        f = barrido(520, 48, q, 2.2)            # el sistema se cae
        out.append((cuadrada(f, t, 0.5) * 0.5 + ruido() * 0.5 * (1.0 - q))
                   * env(i, n, 0.001, 0.0, 1.0, 0.8))
    return out

def terminal(dur=0.42):
    # tres notas subiendo: algo se ha CONECTADO
    n = int(SR * dur); out = []
    notas = [523.25, 659.25, 987.77]
    for i in range(n):
        q = i / n; t = i / SR
        k = min(len(notas) - 1, int(q * len(notas)))
        loc = (q * len(notas)) % 1.0
        e = (1.0 - loc) ** 1.4
        out.append(cuadrada(notas[k], t, 0.5) * e * 0.45 * env(i, n, 0.004, 0.0, 1.0, 0.6))
    return out

def fragmento(dur=0.13):
    n = int(SR * dur); out = []
    for i in range(n):
        t = i / SR
        v = cuadrada(1318.5, t, 0.5) * 0.5 + cuadrada(1975.5, t, 0.25) * 0.3
        out.append(v * env(i, n, 0.002, 0.0, 1.0, 0.55))
    return out

def puerta(dur=0.6):
    n = int(SR * dur); out = []
    for i in range(n):
        q = i / n; t = i / SR
        f = barrido(70, 190, q, 0.8)            # algo pesado que sube
        out.append((sierra(f, t) * 0.5 + ruido() * 0.18 * (1.0 - abs(2 * q - 1)))
                   * env(i, n, 0.05, 0.0, 1.0, 0.45))
    return out

def aviso(dur=0.11):
    n = int(SR * dur); out = []
    for i in range(n):
        t = i / SR
        out.append(cuadrada(1046.5, t, 0.5) * env(i, n, 0.002, 0.0, 1.0, 0.4) * 0.42)
    return out

def portal(dur=0.9):
    n = int(SR * dur); out = []
    notas = [523.25, 659.25, 783.99, 1046.5]
    for i in range(n):
        q = i / n; t = i / SR
        v = 0.0
        for k, f in enumerate(notas):
            arranca = k * 0.13
            if q > arranca:
                v += cuadrada(f, t, 0.5) * (1.0 - (q - arranca)) * 0.3
        out.append(v * env(i, n, 0.01, 0.0, 1.0, 0.7))
    return out

EFECTOS = [("salto", salto), ("aterrizaje", aterrizaje), ("impulso", impulso),
           ("muerte", muerte), ("terminal", terminal), ("fragmento", fragmento),
           ("puerta", puerta), ("aviso", aviso), ("portal", portal)]

if __name__ == "__main__":
    print("sintetizando en %s" % OUT)
    for nombre, fn in EFECTOS:
        guardar(nombre, fn())
    print("LISTO: %d efectos" % len(EFECTOS))
