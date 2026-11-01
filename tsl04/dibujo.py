# -*- coding: utf-8 -*-
"""Herramientas de dibujo 2D con trazo a mano. Genera SVG, sin 3D."""
import math

PAPEL  = "#EDE7D9"
TINTA  = "#2A2622"
GRIS   = "#C6C0B2"
GRIS2  = "#DCD6C8"
CIAN   = "#4FC3E8"
CIANC  = "#A8E2F4"
ROJO   = "#DF4A3C"
AZUL   = "#3E7FD0"
AMAR   = "#F2CE45"

def _r(semilla, i):
    """pseudoaleatorio determinista en [-1,1]: el dibujo sale igual cada vez"""
    x = math.sin(semilla * 127.1 + i * 311.7) * 43758.5453
    return (x - math.floor(x)) * 2.0 - 1.0

class Lamina:
    def __init__(self, w, h, semilla=1.0):
        self.w, self.h, self.s, self.n = w, h, semilla, 0
        self.partes = []

    def _sig(self):
        self.n += 1
        return self.n

    # ------------------------------------------------------------ primitivas
    def linea(self, x1, y1, x2, y2, gr=1.6, col=None, pasadas=2, amp=None):
        col = col or TINTA
        L = math.hypot(x2 - x1, y2 - y1)
        amp = amp if amp is not None else min(2.2, 0.9 + L * 0.012)
        for p in range(pasadas):
            k = self._sig() + p * 17
            a = (x1 + _r(self.s, k) * amp, y1 + _r(self.s, k + 1) * amp)
            b = (x2 + _r(self.s, k + 2) * amp, y2 + _r(self.s, k + 3) * amp)
            c1 = (x1 + (x2 - x1) / 3 + _r(self.s, k + 4) * amp * 1.8,
                  y1 + (y2 - y1) / 3 + _r(self.s, k + 5) * amp * 1.8)
            c2 = (x1 + 2 * (x2 - x1) / 3 + _r(self.s, k + 6) * amp * 1.8,
                  y1 + 2 * (y2 - y1) / 3 + _r(self.s, k + 7) * amp * 1.8)
            self.partes.append(
                '<path d="M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f" fill="none" stroke="%s" '
                'stroke-width="%.2f" stroke-linecap="round" opacity="%.2f"/>'
                % (a[0], a[1], c1[0], c1[1], c2[0], c2[1], b[0], b[1], col,
                   gr * (1.0 if p == 0 else 0.72), 1.0 if p == 0 else 0.5))

    def poli(self, pts, gr=1.6, col=None, cerrar=False, pasadas=2):
        q = list(pts) + ([pts[0]] if cerrar else [])
        for i in range(len(q) - 1):
            self.linea(q[i][0], q[i][1], q[i + 1][0], q[i + 1][1], gr, col, pasadas)

    def caja(self, x, y, w, h, gr=1.6, col=None, sobra=1.6):
        """rectangulo con las esquinas pasadas de largo, como cuando se dibuja rapido"""
        o = sobra
        self.linea(x - o, y, x + w + o, y, gr, col)
        self.linea(x + w, y - o, x + w, y + h + o, gr, col)
        self.linea(x + w + o, y + h, x - o, y + h, gr, col)
        self.linea(x, y + h + o, x, y - o, gr, col)

    def circ(self, cx, cy, r, gr=1.6, col=None, pasadas=2, ry=None):
        ry = ry if ry is not None else r
        col = col or TINTA
        for p in range(pasadas):
            k = self._sig() + p * 23
            n = max(28, int(max(r, ry) * 1.2))
            # ondulacion suave (dos armonicos), no ruido por vertice: si no sale peludo
            f1, f2 = 2 + int(abs(_r(self.s, k) * 2)), 3 + int(abs(_r(self.s, k + 9) * 3))
            p1, p2 = _r(self.s, k + 1) * math.pi, _r(self.s, k + 2) * math.pi
            a1, a2 = 0.016 + abs(_r(self.s, k + 3)) * 0.012, 0.008
            ox, oy = _r(self.s, k + 4) * 1.1, _r(self.s, k + 5) * 1.1
            d = []
            for i in range(n + 1):
                t = (i / n) * math.tau
                rr = 1.0 + a1 * math.sin(t * f1 + p1) + a2 * math.sin(t * f2 + p2)
                x = cx + ox + math.cos(t) * r * rr
                y = cy + oy + math.sin(t) * ry * rr
                d.append(("M" if i == 0 else "L") + "%.1f %.1f" % (x, y))
            self.partes.append('<path d="%s" fill="none" stroke="%s" stroke-width="%.2f" '
                               'stroke-linecap="round" opacity="%.2f"/>'
                               % (" ".join(d), col, gr * (1.0 if p == 0 else 0.7), 1.0 if p == 0 else 0.5))

    def arco(self, cx, cy, r, a0, a1, gr=1.6, col=None, ry=None, pasadas=2):
        ry = ry if ry is not None else r
        col = col or TINTA
        for p in range(pasadas):
            k = self._sig() + p * 31
            n = 22
            f1 = 2 + int(abs(_r(self.s, k) * 2)); ph = _r(self.s, k + 1) * math.pi
            d = []
            for i in range(n + 1):
                t = math.radians(a0 + (a1 - a0) * i / n)
                rr = 1.0 + 0.018 * math.sin(t * f1 + ph)
                d.append(("M" if i == 0 else "L") + "%.1f %.1f"
                         % (cx + math.cos(t) * r * rr, cy + math.sin(t) * ry * rr))
            self.partes.append('<path d="%s" fill="none" stroke="%s" stroke-width="%.2f" '
                               'stroke-linecap="round" opacity="%.2f"/>'
                               % (" ".join(d), col, gr * (1.0 if p == 0 else 0.7), 1.0 if p == 0 else 0.5))

    # -------------------------------------------------------------- rellenos
    def relleno(self, pts, col, op=1.0):
        d = " ".join(("M" if i == 0 else "L") + "%.1f %.1f" % p for i, p in enumerate(pts))
        self.partes.append('<path d="%s Z" fill="%s" opacity="%.2f"/>' % (d, col, op))

    def relleno_caja(self, x, y, w, h, col, op=1.0):
        self.relleno([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], col, op)

    def relleno_circ(self, cx, cy, r, col, op=1.0, ry=None):
        ry = ry if ry is not None else r
        self.partes.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" opacity="%.2f"/>'
                           % (cx, cy, r, ry, col, op))

    def nube(self, cx, cy, r, lobulos=7, gr=1.5, col=None, relleno_col=None):
        pts = []
        for i in range(lobulos * 6):
            t = i / (lobulos * 6) * math.tau
            rr = r * (0.78 + 0.30 * abs(math.sin(t * lobulos / 2.0)) + _r(self.s, self._sig()) * 0.05)
            pts.append((cx + math.cos(t) * rr, cy + math.sin(t) * rr * 0.72))
        if relleno_col:
            self.relleno(pts, relleno_col)
        self.poli(pts, gr, col, cerrar=True, pasadas=1)

    def trama(self, x, y, w, h, ang=32, sep=7, gr=0.7, col=None):
        """rayado diagonal, para sombrear como a lapiz"""
        col = col or TINTA
        a = math.radians(ang)
        dx, dy = math.cos(a), math.sin(a)
        largo = math.hypot(w, h)
        n = int(largo / sep) + 6
        for i in range(n):
            px = x - h * dx + i * sep * dy
            py = y + i * sep * (-dx) + h
            self.linea(px, py, px + dx * largo, py + dy * largo, gr, col, pasadas=1, amp=0.7)

    def recorta(self):
        """marco de la vineta"""
        self.caja(3, 3, self.w - 6, self.h - 6, 2.4, TINTA, sobra=0.8)

    def svg(self, con_marco=True):
        if con_marco:
            self.recorta()
        return ('<svg viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg" '
                'preserveAspectRatio="xMidYMid meet">'
                '<rect width="%d" height="%d" fill="%s"/>%s</svg>'
                % (self.w, self.h, self.w, self.h, PAPEL, "".join(self.partes)))
