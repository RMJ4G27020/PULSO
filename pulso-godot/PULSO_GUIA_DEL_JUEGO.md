# PULSO — Guía completa del juego

**Documento de diseño y funcionamiento**
Versión 1.1 · 20 de octubre de 2026 (niveles 5 y 6 y balizas; el resto, como en la 1.0 del 11 de octubre)
Autor del juego: Jose Guadalupe Rico Moreno

> Este documento describe PULSO **tal y como existe hoy en el código**. Cada cifra
> procede de los scripts, las escenas y la configuración del proyecto en la fecha
> indicada, no de la intención de diseño original. Donde algo está preparado pero
> todavía no se usa, o directamente no existe, se dice expresamente (sección 14).

---

## Índice

1. [Ficha del juego](#1-ficha-del-juego)
2. [La historia](#2-la-historia)
3. [El protagonista: TSL-04](#3-el-protagonista-tsl-04)
4. [Controles](#4-controles)
5. [Mecánicas de movimiento](#5-mecánicas-de-movimiento)
6. [La estela: la mecánica que define el juego](#6-la-estela-la-mecánica-que-define-el-juego)
7. [Los elementos del nivel](#7-los-elementos-del-nivel)
8. [Modos de juego y progresión](#8-modos-de-juego-y-progresión)
9. [La interfaz](#9-la-interfaz)
10. [Sonido y música](#10-sonido-y-música)
11. [Accesibilidad](#11-accesibilidad)
12. [Arte y producción](#12-arte-y-producción)
13. [Anexo técnico](#13-anexo-técnico)
14. [Estado actual y hoja de ruta](#14-estado-actual-y-hoja-de-ruta)
15. [Glosario](#15-glosario)

---

## 1. Ficha del juego

| | |
|---|---|
| **Título** | PULSO |
| **Descripción oficial** | «Puzzle-plataformas de trazo único» (campo `config/description` del proyecto) |
| **Género** | Plataformas 2D con estética 2.5D y un componente de rompecabezas |
| **Motor** | Godot 4.7.2 |
| **Renderizador** | GL Compatibility (el adecuado para móvil) |
| **Plataforma objetivo** | Android (Google Play). Hoy funciona en escritorio; la exportación a Android no está configurada |
| **Resolución lógica** | 640 × 360 píxeles, ventana de 1280 × 720, estiramiento `canvas_items` con aspecto `expand` |
| **Jugadores** | Uno |
| **Idioma del juego** | Español |
| **Conexión** | Ninguna. No hay red, anuncios, compras ni analítica |
| **Tamaño del proyecto** | Unos 21 MB, de los que `arte/` ocupa 12 MB |

### La idea en una frase

PULSO es un juego de plataformas en el que **correr es seguro y pararse mata**:
el personaje deja tras de sí una estela eléctrica que se enciende medio segundo
después de pisarla y que mata si la vuelves a tocar.

### El pilar de diseño

Todo en PULSO sale de una sola regla: **el jugador no puede detenerse**. De ella
se derivan las demás decisiones:

- La música mantiene un pulso constante y no ofrece silencios para respirar.
- Los niveles se construyen como secuencias de verbos (correr, saltar, impulsarse,
  trepar) en las que «esperar» solo cabe donde el juego lo permite.
- Los únicos lugares donde se puede estar quieto, la terminal y las balizas de los
  niveles 5 y 6, son *toma de tierra*.
- El final de la historia depende de esa misma regla: el final feliz consiste en
  que, por fin, el personaje puede pararse.

### El mundo

La acción transcurre en el interior de una computadora enorme: placas de circuito
como plataformas, drones de mantenimiento como enemigos, paquetes de datos que
recorren los buses del fondo. El código de color es estricto y se mantiene en todas
las pantallas: **cian** para lo que es TSL-04 y su estela, **rojo** para lo que
hace daño, **lima** para lo que sirve (terminales, fragmentos, portal) y **ámbar**
para los avisos de poca carga.

---

## 2. La historia

La historia de PULSO se cuenta con dos cinemáticas: una **intro** que se ve al
pulsar JUGAR y un **final** que aparece al completar el tercer nivel. Entre
ambas no hay diálogos ni texto durante el juego: la narración es visual y las
reglas del juego (la estela, la carga que se agota) hacen de continuación.

### 2.1 El método narrativo: láminas que hierven

Las cinemáticas no son vídeo ni animaciones por interpolación. Siguen el método
de *The Binding of Isaac*: cada viñeta son **dos dibujos casi idénticos que se
alternan cada 0,1 segundos** (tres cuadros a 30 fps), de modo que las líneas
«hierven» como si estuvieran dibujadas a mano y vivas. Las láminas están
apoyadas sobre una hoja de papel colocada en un escritorio, y cada hoja se
inclina un poco de una viñeta a otra para dar sensación de manipulación física.

Hay 24 láminas numeradas (de la 1 a la 24), cada una en dos versiones (`a` y `b`),
más el dibujo del escritorio, también en dos versiones. Se generan por código con
un script de Python (`tsl04/laminas.py`) en formato SVG. Intro y final comparten
**el mismo script** (`scripts/cine.gd`): el final es la misma máquina con un
parámetro distinto (`final = true`), para que no puedan desincronizarse al
retocar una de las dos.

### 2.2 Los personajes de la historia

**TSL-04** es la protagonista. Es una celda de prueba de carga: un dispositivo
pensado para medir cuánta energía aguanta el centro de datos, sin función propia.
Se menciona expresamente que «nunca había hecho nada». Es una esfera de luz con
una cara de ojos grandes y mirada curiosa. En la narración se refiere a ella en
femenino.

**NIMBUS-9** es el centro de datos donde transcurre todo. Llevaba catorce años
sin apagarse una sola vez. La historia no le da una voz: se expresa a través de
«la máquina», que clasifica a TSL-04 como **ERROR 04** y ordena borrarla.

**Las tres celdas apagadas.** TSL-04 era la cuarta de cuatro celdas colgadas de
los mismos cables. Las otras tres ya se habían apagado y nadie fue a retirarlas.
Funcionan como advertencia sobre lo que le espera a TSL-04, y como promesa en el
final.

**Los drones de mantenimiento** son el brazo ejecutor de la máquina: cambian de
tarea para perseguir a TSL-04. Son los enemigos que se ven en los niveles.

**«Algo que lo miraba todo»** es la vigilancia del edificio, representada como un
ojo en las láminas. No tiene nombre ni cuerpo: es una presencia constante.

### 2.3 La intro

Dura **64 segundos de láminas** (17 viñetas), más 1,2 s de fundido y 1,6 s de
rótulo final: unos 66,8 segundos en total. Acaba con el rótulo **NIVEL 01** y
pasa directamente al primer nivel. Puede saltarse tras los primeros 0,8 s con la tecla de salto, la de aceptar o la de
pausa, **tocando la pantalla** o con el botón atrás de Android. En un dispositivo con
pantalla táctil, el rótulo dice «Toca para saltar» en lugar de «Espacio para saltar».

El texto de cada lámina, en orden:

| # | Lámina | Duración | Texto |
|---|---|---|---|
| 1 | 10 | 4,0 s | El centro de datos NIMBUS-9 llevaba catorce años sin apagarse ni una sola vez. |
| 2 | 1 | 4,0 s | En su sótano térmico vivía la máquina. Nadie bajaba nunca a verla. |
| 3 | 11 | 3,5 s | De sus cables colgaban cuatro celdas de prueba de carga. |
| 4 | 12 | 4,0 s | Tres ya se habían apagado. Nadie las bajó de ahí. |
| 5 | 2 | 3,5 s | La cuarta se llamaba TSL-04. Nunca había hecho nada. |
| 6 | 13 | 3,5 s | Arriba, algo lo miraba todo. Todo el tiempo. |
| 7 | 3 | 3,5 s | Una noche de tormenta, un rayo cayó sobre el pararrayos. |
| 8 | 4 | 2,5 s | La descarga recorrió el cable de tierra hasta el final. |
| 9 | 5 | 4,0 s | Y TSL-04 abrió los ojos. |
| 10 | 14 | 4,0 s | Dio un paso. El suelo se encendió detrás de ella. |
| 11 | 15 | 4,5 s | Y entendió que no podía volver por donde había venido. |
| 12 | 6 | 4,5 s | La máquina no supo qué era. La llamó ERROR 04. |
| 13 | 7 | 3,0 s | Y mandó borrarla. |
| 14 | 17 | 3,5 s | Los drones de mantenimiento cambiaron de tarea. |
| 15 | 16 | 3,5 s | Las puertas empezaron a cerrarse por sectores. |
| 16 | 18 | 4,0 s | A TSL-04 le quedaba muy poca carga. Y bajaba sola. |
| 17 | 8 | 4,5 s | Así que echó a correr. Y no ha parado desde entonces. |

La intro plantea tres cosas que el juego convierte después en mecánicas: que
**el suelo se enciende detrás de ella** (la estela), que **le queda poca carga y
baja sola** (la barra de carga, que se consume 1,6 % por segundo) y que
**tiene que seguir corriendo** (el pilar de diseño).

### 2.4 El final

El final aparece **después del nivel 3** y, al terminar, el juego continúa en
el nivel 4. Dura 33,5 segundos de láminas (8 viñetas) más el fundido y el rótulo
**FIN**: 36,3 segundos en total. También se puede saltar, igual que la intro.

El storyboard original del juego acababa en la viñeta 9, «el escape», que la intro
nunca utilizó: TSL-04 atraviesa la pared de NIMBUS-9, cruza la ciudad dejando su
estela y llega a una granja. El final recupera esa viñeta y la rodea de seis láminas
nuevas (19 a 24) que **riman con la intro**: cada frase del final contesta a una de
la intro.

| Intro | Final |
|---|---|
| Dio un paso. El suelo se encendió detrás de ella. | Dio un paso. El suelo no se encendió. |
| A TSL-04 le quedaba muy poca carga. Y bajaba sola. | El sol empezó a llenarle la carga. Despacio, sin prisa. |
| Así que echó a correr. Y no ha parado desde entonces. | Y por primera vez desde aquella noche, TSL-04 se paró. |
| Tres ya se habían apagado. | A su lado se encendieron otras tres luces. |
| Arriba, algo lo miraba todo. | Arriba, el ojo lo miraba todo. Pero a ella ya no la vio. |

El texto íntegro del final:

1. Al final del conducto había una rejilla. Y detrás, luz de verdad. (4,0 s)
2. Arriba, el ojo lo miraba todo. Pero a ella ya no la vio. (3,5 s)
3. TSL-04 atravesó la pared de NIMBUS-9 y cruzó la ciudad sin mirar atrás. (4,5 s)
4. Al otro lado había campos. Allí nadie la buscaba. (4,0 s)
5. Dio un paso. El suelo no se encendió. (4,0 s)
6. El sol empezó a llenarle la carga. Despacio, sin prisa. (4,0 s)
7. Y por primera vez desde aquella noche, TSL-04 se paró. (4,5 s)
8. A su lado se encendieron otras tres luces. (5,0 s)

La penúltima frase es la clave del final. Como en PULSO pararse mata, que TSL-04
pueda por fin pararse es el final feliz expresado con la regla del propio juego. El
color amarillo, que no aparece en toda la intro, es en el final la luz del día.

### 2.5 Por qué el final no devuelve al menú

Tras el final, el juego sigue en el nivel 4 y no en el menú principal. La razón es
práctica: JUGAR empieza siempre por la intro y el nivel 1, de modo que si el final
llevara al menú, nadie volvería a ver la chimenea ni los niveles 5 y 6. La
historia se cierra en el tercer nivel; lo que viene después es el juego «de después».
Cambiarlo es una sola línea (`SIGUIENTE_FINAL` en `scripts/cine.gd`). Al menú se
vuelve al pasar el último nivel, el 6.

### 2.6 Garantías de la transición

El paso del nivel 3 al final está diseñado para que **nada se solape** y se respeten
los tiempos de salida de cada nivel:

- La salida del nivel 3 dura lo mismo que la de cualquier nivel: unos 1,5 s.
- El sonido del portal dura 0,90 s y termina antes de que la música empiece a
  apagarse, también a los 0,90 s.
- La música del nivel («circuito») se apaga con el fundido a negro, en su mismo medio
  segundo. Entre niveles normales la música no se corta; solo hacia el final se apaga.
- Nunca hay dos escenas vivas a la vez, ni dos músicas: hay un solo reproductor.
- El tema del final, «libre», entra con la pantalla ya en negro, se va con la imagen
  y el rótulo FIN queda en silencio.
- Si el jugador salta el final, «libre» se corta en seco y el nivel 4 arranca su
  música desde silencio.

Todo esto lo comprueba una prueba automática (`prueba/final`) con 30 afirmaciones
sobre cambios de escena reales.

---

## 3. El protagonista: TSL-04

### 3.1 Identidad visual

TSL-04 es una **esfera luminosa cian** con una cara de ojos grandes y brillantes,
una pequeña sonrisa y rubor en las mejillas. Es deliberadamente simple: tiene que
reconocerse a 48 píxeles de lado (el tamaño de un icono en el cajón de aplicaciones)
y seguir siendo una cara y no una bola. En el juego mide 32 píxeles de ancho,
el equivalente a dos celdas de la rejilla de la estela.

Está modelada en Blender (esfera de 48 × 24 segmentos con un modificador de
subdivisión) y se renderiza a **sprites de 288 × 288 píxeles** que el motor muestra
reducidos a un tercio. El generador admite paletas alternativas (ámbar, violeta y plata) que
usan las otras tres celdas (sección 3.6); TSL-04 es la cian.

Un detalle de diseño: la mayor parte del color de TSL-04 está en el canal azul y el
verde, con casi nada de rojo. Esa elección y la de reservar el rojo para el peligro
hacen que el personaje y las amenazas nunca se confundan, ni siquiera con
daltonismo.

### 3.2 Las doce animaciones

TSL-04 tiene doce animaciones, cada una con su número de cuadros y velocidad:

| Animación | Cuadros | Velocidad | Duración | Bucle | Cuándo se reproduce |
|---|---|---|---|---|---|
| reposo | 12 | 10 fps | 1,20 s | Sí | Quieta en el suelo con carga suficiente |
| correr | 12 | 16 fps | 0,75 s | Sí | En el suelo, velocidad horizontal > 12 px/s |
| giro | 4 | 20 fps | 0,20 s | No | Al cambiar de sentido estando en el suelo |
| salto | 6 | 14 fps | 0,43 s | No | En el aire, subiendo |
| caida | 4 | 12 fps | 0,33 s | Sí | En el aire, bajando |
| aterrizaje | 3 | 18 fps | 0,17 s | No | Al tocar el suelo tras estar en el aire |
| impulso | 5 | 20 fps | 0,25 s | No | Durante el impulso |
| adherencia | 6 | 10 fps | 0,60 s | Sí | Pegada a una pared |
| muerte | 6 | 14 fps | 0,43 s | No | Al morir; se queda en el último cuadro |
| aparicion | 5 | 20 fps | 0,25 s | No | Al nacer o reaparecer |
| carga_baja | 6 | 8 fps | 0,75 s | Sí | Quieta con menos de 25 % de carga |
| victoria | 8 | 12 fps | 0,67 s | No | Al alcanzar el portal |

Las animaciones **giro, aterrizaje, impulso, muerte, aparición y victoria son
«únicas»**: no pueden interrumpirse hasta que terminan. El resto se cambia en cuanto
cambia el estado. La selección sigue un orden de prioridad: primero la adherencia,
luego el aire (salto si sube, caída si baja), después correr, después carga baja,
y por último reposo.

Un detalle de producción: las animaciones de squash y stretch (aplastado y estirado)
conservan el volumen constante. Una versión anterior inflaba al personaje un 18 %
al estirarlo; ahora el volumen se mantiene, y el aspecto es más sólido.

### 3.3 La sombra de contacto

TSL-04 lleva una sombra (`scripts/sombra.gd`) que cumple tres funciones a la vez:
indica dónde está el suelo, indica a qué altura va el personaje y, en el aire,
**anticipa dónde va a caer**, información útil en un juego donde pararse mata.

La sombra se proyecta con un rayo hacia abajo desde los pies hasta 150 píxeles
(`ALTURA_MAX`): está siempre pegada al suelo real, no a una distancia fija. Se
encoge hasta el 42 % de su tamaño y se aclara con la altura; a 150 píxeles
desaparece. Como el salto es de 115 píxeles, en la cima sigue visible. No se
dibuja sobre el vacío ni con el personaje muerto. Se compone con tres elipses
concéntricas de opacidad decreciente para obtener un borde suave, y su opacidad
máxima es de 0,62.

### 3.4 La carga: vida y reloj a la vez

TSL-04 tiene una única estadística: la **carga**, un número de 0 a 100 que empieza
al máximo y actúa a la vez como vida y como cronómetro:

- **Se consume sola** a 1,6 puntos por segundo. Sin recargas, una partida dura como
  mucho 62,5 segundos.
- **Se gasta con las acciones:** el impulso cuesta 3, el pulso de reinicio 25 y
  agarrarse a una pared 1 por segundo.
- **Se recupera** con las terminales (+15) y con los fragmentos (+5 cada uno).
- **Al llegar a 0 muere.**

Esta doble función explica que el juego no necesite un contador de vidas: perder
carga *es* acercarse a perder.

### 3.5 Aparición, gracia y victoria

- **Aparición.** Al empezar o reiniciar, TSL-04 nace una celda por encima del
  punto de aparición (el *anclaje*) con la carga al 100 % y reproduce la animación
  `aparicion`.
- **Gracia.** Tras reaparecer es invulnerable **1,1 segundos** y parpadea para que
  se note. Antes de existir esa gracia, los enemigos la remataban en bucle justo
  al reaparecer.
- **Victoria.** Al tocar el portal, TSL-04 celebra: gracia ampliada a 3 s (para que
  su propia estela no la mate quieta sobre el portal), animación `victoria`, un
  destello lima de 0,55 s y chispas.

---

### 3.6 Las otras tres celdas: TSL-01, TSL-02 y TSL-03

TSL-04 no era la única. Colgaban cuatro celdas de prueba de carga, y las otras tres
se habían apagado antes de que el rayo la despertara. En el final, cuando TSL-04 por
fin se para al sol, «a su lado se encendieron otras tres luces». Son ellas, y se
pueden jugar: cada una despierta con algo que el jugador consigue.

Cada una cambia la mecánica con **una ventaja y un coste**, nunca dos ventajas. Y
ninguna salta menos, corre menos ni cae más deprisa que TSL-04: los niveles están
medidos con su física, así que todas pueden terminarlos. Dos reglas más, que
comprueba `prueba/personajes`: cada una tiene una pega que se siente, y ninguna
muere resbalando por una pared (una celda de 16 px se cruza en 16/46 = 0,348 s, y la
estela tarda 0,35 s en encenderse; por eso la estela de TSL-03 no es más nerviosa).
La duración de la estela no cuenta como coste: correr o aterrizar sobre la propia
estela la vuelve a marcar, y solo importa al cruzarla en el aire o con el impulso.

| | Color | Quién es | Ventaja | Coste | Despierta |
|---|---|---|---|---|---|
| **TSL-01** | ámbar | La primera y la más vieja, hecha para medir descargas lentas | Su estela tarda 0,55 s en encenderse (más margen para dudar) y gasta menos carga (1,3 %/s) | El impulso le cuesta 5 % en vez de 3 | Al ver el final |
| **TSL-02** | violeta | Hecha para picos de carga: va caliente | Corre a 250 px/s, salta 125 px y repite el impulso cada 0,6 s | Gasta 1,9 %/s: la carga dura 53 s en vez de 62 | Al pasar el nivel 4 |
| **TSL-03** | plata | La que más aguantó colgada: se agarra a todo | Trepa sin gastar carga y el pulso le cuesta 15 en vez de 25 | El impulso tarda 1,4 s en volver (0,9 s los demás) | Con los 12 fragmentos |

Se eligen en la pantalla NIVELES (sección 8.6), en la fila de abajo: el selector
enseña su dibujo, su nombre en su color y su rasgo, y se cambia con las flechas, con
Intro o tocándolo. Solo recorre las que están despiertas; si solo hay una, dice cómo
se despierta la siguiente. La estela y las chispas de la muerte salen del color de
cada una, y el modo asistencia dobla el margen de la estela de cada una.

**Estado:** las cuatro se pueden jugar y se ofrecen según vayan despertando. Las
tres nuevas son el mismo modelo 3D que TSL-04 con otra paleta (color de cuerpo, de
emisión, del borde y del rubor) y su propia estela del mismo color; **no tienen
silueta propia**, y rediseñarla es decisión del autor. Los bots recorren los
niveles 1 a 4 con las cuatro; los de los niveles 5 y 6 corren solo con TSL-04.

La carga tiene que alcanzar a ritmo de par con todas: como una terminal da 15 y los
fragmentos son opcionales, cada **tramo** de un nivel (de una baliza a la siguiente,
sección 7.5) cumple `par / tramos × (220 / velocidad) × consumo ≤ 115 %`. Los niveles
1 a 4 son un solo tramo; Lasermania tiene seis y Runthedrun cinco.

## 4. Controles

### 4.1 Teclado

El mapa de entrada está definido en `project.godot`. Hay ocho acciones; varias
tienen más de una tecla.

| Acción | Teclas | Qué hace |
|---|---|---|
| Mover a la izquierda | ← o **A** | Acelera hacia la izquierda |
| Mover a la derecha | → o **D** | Acelera hacia la derecha |
| Saltar | **Espacio**, ↑ o **W** | Salta; también despega de una pared |
| Impulso | **Shift** o **J** | Arrancón horizontal sin estela |
| Accionar terminal | **E** | Acciona al instante la terminal en la que se está |
| Pulso de reinicio | **Q** | Borra toda la estela a cambio de carga |
| Reiniciar nivel | **R** | Reinicia el nivel actual desde cero |
| Pausa | **Esc** (fija) | Abre el menú de pausa |

En las letras (A, D, W, J, E, Q, R) el juego usa **teclas físicas**, es decir, la
posición en el teclado y no la letra impresa. Con un teclado no QWERTY, las teclas
siguen estando en el mismo sitio. Las flechas, Espacio, Shift y Escape se asignan
por código de tecla.

En los menús se usan las acciones estándar de interfaz: flechas arriba y abajo para
moverse, y aceptar para elegir.

### 4.2 Un detalle importante: la terminal se acciona sola

La terminal ya no exige pulsar nada. Se activa **sola tras 0,45 segundos encima**.
Es seguro porque la terminal es toma de tierra (sección 6). La razón fue táctil:
un botón más en pantalla es un botón que tapa el juego. La tecla E sigue existiendo
para quien quiera dispararla al instante.

### 4.3 Controles táctiles

En móvil no hace falta ninguna tecla. Los mandos solo se crean si el dispositivo
tiene pantalla táctil (`DisplayServer.is_touchscreen_available()`); en un
escritorio estorbarían. Inyectan las mismas acciones que el teclado, así que el
código del personaje no sabe de qué dispositivo viene la orden.

**Joystick flotante.** Ocupa el 45 % izquierdo de la pantalla y **nace donde el
jugador pone el pulgar**, en lugar de estar en una posición fija: uno fijo obliga
a mirar abajo para encontrarlo, y en este juego no se puede apartar la vista. Tiene
un radio de 52 px y una zona muerta de 9 px. No nace en el 30 % superior de la
pantalla, para no chocar con el botón de pausa ni con el HUD.

**Tres botones a la derecha**, de 38 px de radio (unos 17 mm en un móvil de 6
pulgadas, para que un dedo entre de sobra):

- **Saltar**, el mayor y más accesible, en la esquina inferior derecha.
- **Impulso**, a su izquierda.
- **Pulso**, encima del salto.

**Botón de pausa**, arriba en el centro, de 26 px de radio. Es el único que no se
busca a ciegas en plena carrera, así que tiene menos área, para que no se trague
toques destinados al HUD o al salto. No inyecta la acción de pausa (eso no generaría
ningún evento) sino que emite una señal.

**Multitáctil real.** Se mueve con un pulgar mientras se salta con el otro, y soltar
uno no suelta el otro. Los botones ganan sobre la zona de movimiento: si un pulgar
grande cae sobre el borde, salta en vez de mover. Al perder el foco (por ejemplo,
por una llamada) se sueltan todas las acciones, o el personaje seguiría corriendo
solo al volver. Al reanudar desde la pausa también se sueltan.

**Botón atrás de Android.** Hace lo que se espera en cada pantalla:

| Dónde | Qué hace atrás |
|---|---|
| En un nivel | Abre la pausa; si ya está abierta, la cierra |
| En una cinemática | La salta |
| En CONTROLES o en los créditos | Vuelve al menú |
| En el menú principal | La primera vez lleva a SALIR y avisa «Atrás otra vez para salir»; la segunda, antes de 2 s, sale |

Salir del menú pide dos pulsaciones por la misma razón que SALIR se mantiene 3 s:
que un atrás pulsado sin querer no cierre el juego. Para que todo esto llegue al
juego, el proyecto tiene `application/config/quit_on_go_back` en `false`; con el
valor de fábrica (`true`), Godot cerraba la aplicación en cuanto se pulsaba atrás,
desde cualquier pantalla.

### 4.4 Cambiar las teclas

Las teclas se pueden **reasignar** desde el menú principal → **OPCIONES**, que abre la
pantalla **CONTROLES**. Cada acción tiene hasta **tres teclas** (las mismas que trae
saltar de fábrica: Espacio, flecha arriba y W).

| En la pantalla CONTROLES | Qué hace |
|---|---|
| Flechas arriba y abajo | Cambiar de acción |
| Flechas izquierda y derecha | Elegir cuál de sus teclas, o el hueco vacío para añadir una |
| Intro | Ponerse a escuchar: la siguiente tecla que se pulse se asigna ahí |
| Supr o Retroceso | Quitar la tecla elegida |
| Esc | Cancelar la escucha, o volver al menú |

Mientras escucha, el hueco muestra un guion que parpadea y una barra que se gasta: **a
los 5 segundos sin tecla, la escucha se cancela sola** sin cambiar nada. Un clic
también la cancela. La fila **Restaurar teclas de fábrica** pide dos pulsaciones y
muestra cuántos huecos difieren de fábrica; las teclas cambiadas llevan un pequeño
cuadrado lima.

Las reglas, que se cumplen siempre:

- **Ninguna acción se queda sin tecla.** No se puede quitar la última. Si se asigna
  a una acción la única tecla de otra, las dos **se intercambian** (la otra se queda
  con la tecla que había en ese hueco); si el hueco estaba vacío y no hay nada que
  dar a cambio, se rechaza.
- **Ninguna tecla está en dos acciones.** Si la otra acción tenía más teclas, la tecla
  simplemente pasa de una a otra. El pie de la pantalla lo avisa en ámbar y la fila
  afectada se marca un momento.
- **La pausa es siempre Esc** y no se reasigna: es la salida de emergencia de
  cualquier configuración que salga mal.
- Solo se aceptan teclas pensadas para jugar: letras, cifras, signos, flechas, Shift,
  Ctrl (salvo en macOS, donde Ctrl con las flechas son atajos del sistema), Alt,
  Intro, Tab, F1 a F12 y, del teclado numérico, `* / - +` e Intro. Las cifras del
  numérico no, porque con Bloq Num apagado se convierten en flechas. Esc, Cmd, los
  bloqueos (Mayús, Num, Despl), el volumen, las teclas multimedia y Atrás se rechazan.

Las teclas asignadas se guardan **por posición física**: si el jugador cambia la
distribución del teclado, la tecla sigue en el mismo sitio de la mano. En pantalla se
nombran con lo que lleva impreso su teclado (en uno español, la Ñ y no «;»). Las
flechas se dibujan, porque la fuente del juego no tiene esos caracteres.

La reasignación es solo de teclado: los mandos táctiles no cambian.

---

## 5. Mecánicas de movimiento

Todo el movimiento está en `scripts/jugador.gd` y se expresa con parámetros
exportados que se pueden ajustar sin tocar el código. La tabla recoge los valores
actuales.

| Parámetro | Valor | Significado |
|---|---|---|
| Velocidad máxima | 220 px/s | Subida respecto a los 180 del diseño inicial, para cruzar los huecos de los niveles abiertos |
| Aceleración | 1.400 px/s² | Tiempo hasta velocidad máxima: 0,16 s |
| Frenado | 1.800 px/s² | Se detiene en 0,12 s |
| Altura de salto | 115 px | 7,2 celdas; hacen falta para huecos de 4 veces el personaje |
| Gravedad | 980 px/s² | |
| Factor de caída | 1,6 | La gravedad es 1,6 veces mayor al bajar |
| Caída máxima | 520 px/s | Velocidad terminal |
| Coyote time | 0,10 s | Margen para saltar tras dejar el borde |
| Buffer de salto | 0,12 s | El salto pulsado poco antes de aterrizar se recuerda |
| Impulso: velocidad | 340 px/s | |
| Impulso: duración | 0,18 s | |
| Impulso: espera | 0,90 s | Tiempo entre impulsos |
| Deslizamiento en pared | 46 px/s | Caída pegado a una pared |
| Gracia | 1,1 s | Invulnerabilidad al reaparecer |

### 5.1 Correr

Correr es acelerar hasta 220 px/s con una aceleración de 1.400 px/s². Al soltar la
dirección, el frenado es aún más fuerte (1.800 px/s²) para que el personaje responda
con precisión. Si el jugador cambia de sentido estando en el suelo, se reproduce
la animación `giro` antes de arrancar en el otro sentido.

### 5.2 Saltar

La velocidad de salto sale de la altura deseada con la fórmula clásica:
`v = √(2 · g · h) = √(2 · 980 · 115) ≈ 474,8 px/s`. Subir tarda 0,48 s.

El salto tiene cuatro refinamientos, todos pensados para que el juego perdone
errores de ejecución pero no de decisión:

1. **Altura variable.** Si el jugador suelta el botón mientras sube, la velocidad
   vertical se reduce al 45 %, y con ella la altura del salto al 20 %. Una pulsación
   breve da un salto corto; una larga, el salto completo.
2. **Caída reforzada.** Al descender, la gravedad se multiplica por 1,6. Eso
   acorta la parte aérea del salto y hace que el personaje se sienta pesado y
   controlable, no flotante. El descenso desde la cima tarda unos 0,38 s.
3. **Coyote time (0,10 s).** Tras salir de una plataforma se puede saltar durante
   un instante, como si aún se estuviera en el suelo. Evita la frustración de
   saltar «un poco tarde».
4. **Buffer (0,12 s).** Si se pulsa saltar justo antes de aterrizar, el salto se
   guarda y se ejecuta al tocar el suelo.

Con estos valores, un salto en llano a velocidad máxima cubre del orden de 190
píxeles en horizontal (cálculo con la gravedad reforzada de la caída).

### 5.3 El impulso

El impulso lanza al personaje en horizontal a 340 px/s durante 0,18 s: unos 61
píxeles de recorrido, casi cuatro celdas. Tiene tres rasgos que lo definen:

- **No registra estela.** Mientras dura, el personaje no deja marcas en la rejilla.
  Ese hueco es la herramienta del juego: permite cruzar zonas ya pisadas.
- **Cuesta 3 de carga y tiene 0,9 s de espera** entre usos.
- Durante el impulso no se aplica la gravedad ni se puede saltar: es un movimiento
  recto.

También amplía el alcance de los saltos: aporta un ancho extra de hueco de
`(340 − 220) · 0,18 ≈ 21,6` píxeles.

### 5.4 La adherencia a la pared

El personaje se **pega a una pared** si se cumplen cuatro condiciones a la vez:
está en el aire, solo toca una pared (no el suelo), está cayendo y el jugador
empuja hacia ella. Pegado, desliza hacia abajo a 46 px/s en lugar de caer, mira
hacia el lado opuesto a la pared y consume 1 punto de carga por segundo.

Desde la pared se puede **saltar**: el salto sale con una velocidad vertical igual
a la de un salto normal y una velocidad horizontal de 242 px/s (220 · 1,1) en
sentido contrario a la pared. Medido en el motor, **cada salto de pared sube 113
píxeles**, contra los 100 que predecía la física; cuatro saltos suben un pozo
entero.

La adherencia estuvo programada y animada desde el principio, pero los primeros
niveles no tenían una sola pared y no se disparaba nunca. El nivel 4 («La
chimenea») la rescata.

Las paredes tienen su propia textura, diferente a la del suelo, por una razón de
honestidad visual: las plataformas llevan una tira cian en el canto superior que
significa «aquí se pisa». Repetir esa tira en las paredes engañaría al jugador. En
las paredes, las pistas del circuito van en vertical y la luz está en los cantos
laterales, que es de donde se agarra.

### 5.5 El pulso de reinicio

El pulso (tecla Q) **borra de golpe toda la estela** a cambio de 25 puntos de
carga, y solo puede usarse si hay más de 25. Es la válvula de escape cuando el
jugador se ha encerrado con su propio rastro; cuesta casi un cuarto de la vida y por
eso se usa con cuidado.

### 5.6 Morir

El personaje muere de cuatro maneras:

1. Tocando un peligro encendido (rojo).
2. Pisando una celda de estela que ya está activa (sección 6).
3. Quedándose sin carga.
4. Cayendo por debajo del límite del nivel (el vacío).

Al morir se encadena una secuencia de efectos que enfatiza el golpe:

- Una **congelación de 0,08 s** de todo el juego.
- Un **destello blanco**.
- Una **sacudida de pantalla de 3 píxeles**.
- Una **aberración cromática** que se disuelve en 0,2 s.
- **24 chispas** como máximo.
- **Vibración del móvil de 70 ms**, si está activada. Por debajo de unos 30 ms muchos
  motores de vibración ni arrancan, y por encima de unos 120 se nota como zumbido y
  no como golpe.

Después hay una pausa de **0,85 segundos en tiempo real** (para que los enemigos no
rematen en bucle antes de que el jugador reaccione) y el nivel se reinicia: se
restauran el cronómetro a cero, la puerta, la terminal, los fragmentos, el
personaje y todos los peligros a su pose inicial. En los niveles 5 y 6, si ya se ha
pisado una baliza, no se reinicia el nivel: se reaparece en ella (sección 7.5).

---

## 6. La estela: la mecánica que define el juego

### 6.1 Qué es y cómo funciona

TSL-04 deja tras de sí un rastro eléctrico en el suelo que dura 3 segundos. Se
enciende **0,35 segundos después de haber sido pisado** y desde ese momento mata
al contacto. Esa demora de 0,35 s es lo que hace que correr sea seguro: la
estela siempre se enciende detrás. Pararse, en cambio, significa seguir pisando una
celda que se enciende bajo los pies.

La estela se implementa como una **rejilla de marcas de tiempo** (`scripts/rejilla_estela.gd`),
no como objetos sueltos. El espacio se divide en celdas de 16 píxeles; cada celda
guarda únicamente el instante en que se pisó. **Morir es restar dos números.** El
coste no crece con la longitud del recorrido: una partida de una hora tiene el
mismo coste por cuadro que una de diez segundos, porque las marcas viejas se purgan.

### 6.2 El ciclo de vida de una celda

| Edad de la celda | Estado | Qué ocurre |
|---|---|---|
| 0 – 0,35 s | Encendido | Animación de encendido. **No mata todavía** |
| 0,35 – 2,60 s | Activa | Mata si el jugador la toca |
| 2,60 – 3,00 s | Aviso | Parpadea durante los últimos 0,4 s. Sigue matando |
| 3,00 – 3,35 s | Apagado | Se dibuja un instante más, pero ya no mata |
| Más de 3,35 s | Eliminada | La celda se borra de la memoria |

Visualmente, cada celda se representa con láminas renderizadas en Blender (un
sprite de 32 píxeles por celda de 16) y una **cinta continua** que une las celdas
consecutivas para que el trazo se lea como una línea y no como cuadros sueltos. La
cinta se hace más fina y translúcida con la edad. Los saltos y las caídas no dejan
cinta.

### 6.3 Qué marca estela y qué no

- **Sí marca:** correr por el suelo; estar pegado a una pared (la celda junto a la
  pared se marca, así que cada pared sirve una vez).
- **No marca:** estar en el aire, durante el impulso, y estar sobre una
  plataforma que pertenezca al grupo `sin_estela`.

Aunque el impulso no marca estela, sí comprueba la celda donde está: no se puede
atravesar una celda activa solo por ir impulsado.

### 6.4 La toma de tierra

Hay un sitio en cada nivel donde el jugador **tiene** que estar quieto: la terminal.
Para que sea posible, la terminal es una **toma de tierra**: descarga el pulso, así
que la estela no se enciende encima. La zona de tierra se ensancha 16 píxeles a cada
lado de la terminal, hasta donde llega el aviso de interacción, para que no se pueda
morir de pie en un lugar donde el juego pide esperar.

En los niveles 1 a 4 es la única excepción a la regla de no pararse, y por eso es
también el único sitio donde el personaje puede descansar y donde la animación
`carga_baja` es alcanzable. En los niveles 5 y 6 hay otra: las **balizas** (sección
7.5) también son toma de tierra, y sirven para pararse a esperar el hueco de un
láser.

### 6.5 Ritmo de lectura: por qué 0,35 s

El valor de 0,35 s no es caprichoso. Está por debajo del tiempo de reacción ante una
elección, de 0,4 a 0,5 segundos en adultos. Eso significa que el juego normal exige
**anticiparse**, no reaccionar: el jugador tiene que saber por dónde va a correr antes
de hacerlo. Es lo que da al juego su carácter de rompecabezas veloz.

### 6.6 El modo asistencia

El **modo asistencia** (activable desde la pausa, apagado por defecto) alarga ese
retardo de **0,35 a 0,70 segundos**. Esa cifra concede una reacción completa de
margen al jugador que la necesite, y **pararse sigue siendo un error**: la celda
sigue matando, solo que más tarde. La estela, el resto de peligros y la carga no
cambian.

Tres cuidados que acompañan a esta función:

- **Con la asistencia apagada, el juego es exactamente el de siempre.** Una prueba
  automática lo comprueba al milisegundo.
- **La animación de encendido se estira al retardo efectivo.** Si no, con 0,70 s la
  celda parecería encendida del todo a los 0,35 s sin matar aún, y le mentiría al
  jugador. Así «encendida del todo» sigue significando «ya mata».
- **Se aplica en caliente**, sin reiniciar el nivel: reiniciar para cambiar un
  ajuste castigaría precisamente a quien lo busca porque le cuesta.

### 6.7 El reloj de la estela

La rejilla tiene **su propio reloj**, que avanza solo cuando el nodo lo hace. No usa
el reloj de pared del sistema. La razón: si lo usara, al pausar el juego el reloj
seguiría corriendo, las celdas envejecerían durante la pausa y, al reanudar, la estela
mataría al jugador por una celda que no había tenido tiempo de ver. Con reloj propio,
pausar congela la estela, y además la congelación de 0,08 s de la muerte congela
también la estela. Una partida repetida con las mismas pulsaciones produce siempre la
misma secuencia de celdas.

---

## 7. Los elementos del nivel

### 7.1 El circuito de un nivel: terminal, puerta, portal

Cada nivel se completa con tres elementos encadenados:

1. **La terminal** (interruptor): hay que alcanzarla y quedarse encima. Se acciona
   sola a los 0,45 s o al instante con E. Al accionarse abre la puerta, devuelve
   15 puntos de carga, y produce un destello lima, una sacudida y chispas.
2. **La puerta**: bloquea el paso hasta que se abre la terminal. Se abre con una
   animación y un sonido propio.
3. **El portal** (salida): al tocarlo con la puerta abierta, el nivel termina. Si la
   puerta sigue cerrada, el portal no hace nada.

El **anclaje** es el punto de aparición: marca dónde reapareces tras morir (en los
niveles 5 y 6, hasta que pisas una baliza; sección 7.5). No guarda la partida: solo
sirve para colocar al jugador.

### 7.2 Los fragmentos

Cada nivel tiene **3 fragmentos**, cristales en forma de rombo de
color lima. Recoger uno da 5 puntos de carga y suena un tono más agudo que el
anterior, de modo que se oye el progreso. Son opcionales: no hace falta cogerlos
para terminar el nivel, pero se anotan en el guardado y se muestran en el HUD.
Se reponen al morir, porque el nivel se reinicia entero; con una baliza pisada no
se reponen, porque reaparecer en ella no deshace lo hecho (sección 7.5).

### 7.3 Los peligros: una familia con una regla

Todos los peligros heredan de una clase base (`Peligro`) y siguen la regla del diseño
original: **si es rojo, hace daño**. Cada peligro se apunta él solo al grupo
`peligro` desde la clase base: si dependiera de que cada escena lo declarase, bastaría
olvidarlo en una para que ese peligro no se reiniciara nunca al morir.

Todos los peligros avisan antes de matar, **con luz y movimiento, nunca solo con
sonido**: mucha gente juega en silencio, y un peligro que solo avisara con audio
sería injusto. Además, los efectos de aviso (una pequeña sacudida y un destello rojo)
solo se disparan si el jugador está lo bastante cerca para verlos, para que la pantalla
no se sacuda sin motivo.

#### Pinchos

Púas fijas que no se apagan nunca. Son el peligro más simple: se rodean.

#### Bloque pulsante

Un bloque rojo con un ciclo de 2 segundos: **apagado 0,90 s, aviso 0,35 s y
encendido 0,75 s**. Solo mata encendido. Al encenderse, mata a quien ya estuviera
dentro. Cada bloque tiene un desfase configurable para que no latan todos a la vez, lo
que convierte un pasillo con varios en un ritmo que hay que leer.

#### Láser

Un emisor que dispara un haz vertical de 6 celdas de largo (96 px) y 7 píxeles de
ancho. Su ciclo es de 2,5 segundos: **reposo 1,20 s, carga 0,50 s (aviso) y
disparo 0,80 s**. También tiene desfase configurable. Mientras carga cambia de
animación, que es el aviso visual. En Lasermania (nivel 5) cada láser lleva su
propio largo y sus propios tiempos (sección 8.3).

#### Dron de purga

El enemigo móvil básico. Patrulla un tramo de 120 píxeles a 46 px/s; si el jugador
entra en su campo de visión de **190 píxeles**, se pone en alerta, suelta un chispazo
rojo y persigue a **118 px/s** sin rendirse. Es más lento que el jugador corriendo,
pero más rápido que el jugador dudando.

Su particularidad es que **tiene masa**: la velocidad solo puede cambiar a 110 px/s².
De ahí salen, sin programarlas expresamente, dos comportamientos que se leen como
físicos:

- Se **pasa 5,7 px del extremo** de su patrulla antes de dar la vuelta.
- **Tarda en arrancar** cuando te ve.

Se **ladea hasta 24°** hacia el lado hacia el que acelera, porque un cuadricóptero no
tiene otra forma de empujar de lado. Y flota con un cabeceo de 2,6 px de amplitud,
solo en el sprite, no en el cuerpo, para que el área de daño no dé saltos.

#### Torreta zapadora

Un emisor de techo con ciclo de cuatro estados: **reposo, apunta, dispara, reposo**.
Si el jugador está a menos de 210 píxeles y han pasado 1,10 s de espera, empieza a
**apuntar**. Durante 0,50 s gira hacia el jugador y luego dispara un haz de 150
píxeles durante 0,35 s, con un retroceso de 6 px del emisor.

Su giro es un **oscilador amortiguado** (ω = 15,5 rad/s, ζ = 0,48): acelera hacia el
objetivo y se pasa un 18 %, para asentarse en 0,53 s, justo dentro del medio segundo
que dura el apuntado. **Ese vaivén es el aviso.** El jugador ve cómo la torreta
oscila antes de disparar, y puede usar ese tiempo para moverse.

### 7.4 Plataformas y geometría

Las plataformas son **bloques de placa de circuito** modelados en Blender: sustrato,
pistas de cobre en ángulo recto, pads con vía y aletas de disipador. En el canto
superior llevan la tira cian que marca la superficie pisable. Las paredes usan otra
textura (sección 5.4). Los niveles escritos a mano tienen reglas de diseño medidas:

- El hueco entre plataformas es de 112 px, o **4,0 veces el ancho del personaje**.
- La separación vertical entre la ida y la vuelta es de 128 px (4,6 veces).
- El aire libre sobre las plataformas es de 96 px (3,4 veces).
- Una **subida de 2 celdas admite un hueco de 3; una subida de 3 exige un hueco de 2**.
  El verificador de niveles exige 56 px de holgura en cada salto de subida.

### 7.5 Las balizas

Las **balizas** son los puntos de control de los dos niveles grandes, Lasermania y
Runthedrun (`scripts/baliza.gd`, `escenas/obstaculos/Baliza.tscn`). Reusan el
dibujo del anclaje: una baliza es un anclaje que se activa al pasar. Los niveles 1
a 4 no tienen ninguna.

Existen por una cuenta sencilla: una carga completa dura 62 s y morir significaba
empezar el nivel otra vez. Un nivel de 500 celdas no cabe en una sola carga, ni se
puede repetir entero cada vez que te coge un láser.

La primera vez que se pisa, una baliza hace dos cosas:

1. **Recarga la carga a tope** (100 %).
2. **Pasa a ser el punto de reaparición.** El HUD lo dice con «punto de control»
   durante 1,6 s.

Y además es **toma de tierra**, como la terminal (sección 6.4): la estela no se
enciende encima, así que es, con la terminal, el único sitio donde se puede parar,
por ejemplo a esperar a que se apague un láser.

Al morir con una baliza pisada se **reaparece en ella**, con la carga a tope y los
peligros en su pose de partida, pero **sin deshacer** los fragmentos cogidos, la
terminal ni la puerta, y **sin parar el cronómetro**: las muertes cuestan tiempo. El
reinicio completo (la tecla R o «Reiniciar nivel» en la pausa) borra las balizas y
devuelve al anclaje. En los niveles sin balizas, morir sigue siendo empezar de nuevo.

Las balizas no se guardan: un punto de control vive mientras dura el nivel.

---

## 8. Modos de juego y progresión

### 8.1 Estructura general

PULSO tiene **una única progresión lineal** de seis niveles, que empieza en la
intro y, tras el nivel 6, vuelve al menú principal. La primera vez, JUGAR la recorre
desde el principio; en cuanto se ha pasado algún nivel, JUGAR abre la pantalla
**NIVELES** (sección 8.6), desde la que se entra en cualquier punto ya alcanzado de
esa misma cadena:

```
Menú principal
  └─ JUGAR
       ├─ Intro (cinemática, 64 s de láminas)
       ├─ Nivel 1 · Ida y vuelta
       ├─ Nivel 2 · El corredor
       ├─ Nivel 3 · El nudo
       ├─ Final (cinemática, 33,5 s de láminas)
       ├─ Nivel 4 · La chimenea
       ├─ Nivel 5 · Lasermania
       ├─ Nivel 6 · Runthedrun
       └─ Menú principal
```

### 8.2 Los seis niveles

Los tres primeros son **archipiélagos abiertos sobre el vacío**: sin marco, sin
techos, y caerse mata. El cuarto es un pozo vertical. El quinto y el sexto son
mucho más largos, se recorren en un solo sentido y tienen balizas (sección 8.3).
Cada nivel tiene un `par`, el tiempo objetivo en segundos, que el HUD muestra junto
al cronómetro. Los seis suman **401 segundos** de recorrido ideal (216 los cuatro
primeros).

| Nivel | Nombre | Par | Fragmentos | Límite de caída | Peligros colocados |
|---|---|---|---|---|---|
| 1 | Ida y vuelta | 40 s | 3 | 688 px | Ninguno |
| 2 | El corredor | 52 s | 3 | 784 px | 2 bloques pulsantes, pinchos, 1 dron, 1 láser |
| 3 | El nudo | 66 s | 3 | 944 px | 2 bloques pulsantes, 1 dron, pinchos, 1 torreta zapadora, 1 láser |
| 4 | La chimenea | 58 s | 3 | 848 px | 1 dron, 1 láser |
| 5 | Lasermania | 110 s | 3 | 1.616 px | 16 láseres |
| 6 | Runthedrun | 75 s | 3 | 1.280 px | 10 drones de purga, 2 tiras de pinchos |

**Nivel 1 · Ida y vuelta.** El nivel de aprendizaje. No lleva peligros: enseña la
estela, el salto, el circuito terminal-puerta-portal y los fragmentos. Como indica su nombre, tiene una ida y una vuelta separadas en vertical (128 px, 4,6 veces el personaje).

**Nivel 2 · El corredor.** Introduce los peligros: bloques pulsantes, pinchos, un dron
y un láser. Su nombre y su par (52 s) lo sitúan como el recorrido más largo y de más ritmo de los tres primeros.

**Nivel 3 · El nudo.** El primer nivel con todos los tipos de peligro, incluida la
torreta zapadora. Es el que cierra la historia: su portal da paso al final.

**Nivel 4 · La chimenea.** Su corazón es un **pozo de 5 celdas de ancho y 22 de alto**
que solo se sube saltando de pared a pared, y que rescata la mecánica de adherencia.
Cuatro saltos de pared suben el pozo entero.

### 8.3 Los niveles grandes: Lasermania y Runthedrun

Tras el cuarto nivel vienen dos niveles mucho más largos que los anteriores, hechos
a mano como los otros cuatro, y al pasar el sexto se vuelve al menú principal. Hasta
el 20 de octubre de 2026 en ese lugar había niveles generados sin fin; se quitaron a
petición del autor y los sustituyen estos dos.

| | Nivel 5 · Lasermania | Nivel 6 · Runthedrun |
|---|---|---|
| Ancho | 545 celdas | 515 celdas |
| Del anclaje al portal | **8.320 px**, unas 5,5 veces el nivel 1 entero | **7.664 px** |
| Par | 110 s | 75 s |
| Balizas | 5, es decir, **6 tramos** de carga | 4, es decir, **5 tramos** |
| Peligros | 16 láseres | 10 drones de purga y 2 tiras de pinchos |
| Fragmentos | 3 | 3 |

Los dos se recorren **en un solo sentido**: se aparece a la izquierda y el portal está
al fondo a la derecha, con la terminal antes y la puerta justo delante del portal. No
hay que volver. Las balizas (sección 7.5) reparten el recorrido en tramos, y cada uno
empieza con la carga a tope.

#### Lasermania

Un nivel de **cortinas de láser**, en seis tramos, con una baliza al empezar cada uno
salvo el primero:

1. **La calle**: un pasillo llano de 100 celdas con cuatro cortinas que lo cruzan
   entero.
2. **La escalera**: cuatro peldaños que suben, con cortinas que cruzan dos de los
   saltos.
3. **La segunda calle**, más corta, con cuatro cortinas de tiempos distintos, para que
   no se pueda aprender un solo ritmo.
4. **Otra escalera**, con cortinas en dos saltos (llevaba dos torretas y se quitaron: una vigilaba el sitio donde se espera a una cortina y la otra pedía cebarla),
   sobre el tercer y el cuarto peldaño.
5. **El descenso**: peldaños que bajan 9 filas con huecos de 10, y cortinas en los dos
   últimos saltos.
6. **El final**: un pasillo con dos cortinas, la terminal en una repisa 6 filas por
   encima (hay que subir y volver a bajar), la puerta y el portal.

Cada uno de los 16 láseres lleva sus propios tiempos: el reposo, el disparo y el
desfase cambian de uno a otro, y la carga (el aviso) es siempre de 0,5 s. De los tres
fragmentos, dos flotan entre las cortinas de las calles, a 6 filas del suelo, y se
cogen saltando entre haz y haz; el tercero está sobre el primer peldaño del descenso.

Una regla que salió de construirlo: en las escaleras, el emisor de cada láser cuelga
de un bloque sólido, y ese bloque tiene que quedar por encima de donde llega la cabeza
en un salto, 8,9 filas sobre la superficie de la que se salta (9,6 con TSL-02). La
primera versión los ponía más bajos y la cabeza chocaba con ellos; está corregido.

#### Runthedrun

Un nivel para **correr**: una ruta larga de plataformas en un solo sentido, con huecos
de 5 a 9 celdas y pequeñas subidas y bajadas. Los drones de purga cuelgan 11 filas por
encima de la ruta, más arriba de donde llega un salto: te ven al pasar por debajo,
bajan y **te persiguen para siempre**, a 118 px/s contra los 220 del jugador. Quien
sigue corriendo se los deja atrás; quien duda los va juntando detrás.

- Un dron cuelga sobre la salida y echa a perseguirte en cuanto te mueves: el nivel
  empieza corriendo.
- Otros seis están repartidos por la ruta, nunca a menos de 13 celdas de una baliza.
- Las 2 tiras de pinchos van en plataformas largas, de 26 celdas, a 13
  del principio.
- Los 3 fragmentos están a 5 filas sobre otras tantas plataformas: se cogen con un
  salto, sin parar.
- Al final, la terminal está en una plataforma larga sin drones delante; luego vienen
  la puerta, el portal y tres drones que se despiertan al pasar: el último tramo es a
  la carrera.

Las plataformas de la ruta se sortearon con `random.Random(6)` en `grandes.py`, y cada
hueco está limitado por las mismas fórmulas de alcance que el resto de niveles. La
escena es fija: es siempre la misma, no se genera al jugar.

#### Cómo se construyen

`tsl04/grandes.py` monta los dos con piezas (calles, escaleras, balizas) y
`disena_niveles.py` los lee igual que a los otros cuatro: los mismos bloques en celdas
de 16 px y las mismas comprobaciones de alcance. `python3 disena_niveles.py --solo
n5_lasermania` escribe solo esa escena. Los cuatro niveles originales siguen saliendo
del script idénticos byte a byte.

#### Que se puedan terminar

Una prueba automática (`prueba/grandes`) comprueba la estructura de los dos niveles,
el funcionamiento de las balizas y que se pueden recorrer, con bots que corren de la
aparición al portal:

| Bot | Nivel | Llega al portal en | Muertes |
|---|---|---|---|
| Solo la geometría (sin peligros) | Lasermania | 38 s de juego | 0 |
| Solo la geometría (sin peligros) | Runthedrun | 35 s | 0 |
| Paciente: espera a que se apague cada láser | Lasermania | 45 s | 0 |
| Corredor, con todos los drones | Runthedrun | 39 s | 1 (lo alcanza un dron una vez; pasa al reaparecer) |
| Geometría, con **TSL-02** | Lasermania | 33 s | 0 |
| Corredor con drones, con **TSL-02** | Runthedrun | 31 s | 0 |
| Paciente, con **TSL-02** | Lasermania | 37 s | 0 |

Además, cada recorrido comprueba que **se pisan todas las balizas**.

**Los bots demuestran que cada nivel se puede pasar, no que sea justo ni divertido
para una persona: nadie los ha jugado a mano todavía.**

Dos lecciones de diseño que dejaron los bots, las dos en Runthedrun:

- **Los pinchos no pueden ir donde aterriza el salto anterior** (de 6 a 8 celdas
  pasado el hueco) **ni en medio de una plataforma corta**, porque el salto que los
  esquiva acaba pasado el borde. Por eso solo están en las plataformas de 26 celdas, a
  13 del principio.
- **Los drones a 6 filas del suelo chocaban con cada salto** que se diera debajo de
  ellos. Por eso cuelgan a 11.

### 8.4 Flujo de un nivel

Al entrar en un nivel ocurre, en este orden:

1. El nivel se monta: HUD, fundido, menú de pausa y, solo si hay pantalla táctil,
   los mandos.
2. TSL-04 se coloca en el anclaje, con la carga al 100 % y la animación de aparición.
3. La pantalla se abre desde negro en **0,35 s**.
4. Empieza a sonar «circuito». Si ya sonaba, no se reinicia.

En los niveles 5 y 6, al **pisar una baliza** por primera vez (sección 7.5):

1. La carga vuelve al 100 %.
2. La baliza pasa a ser el punto de reaparición.
3. El HUD dice «punto de control» durante 1,6 s.

Al **morir**, tras la pausa de 0,85 s, se reaparece en la última baliza pisada, con la
carga a tope y los peligros en su pose de partida, pero sin deshacer fragmentos,
terminal ni puerta y con el cronómetro en marcha. Sin baliza pisada, y siempre en los
niveles 1 a 4, el nivel se reinicia entero.

Al **completar** un nivel:

1. Suena el portal (0,90 s) y TSL-04 celebra.
2. A los 0,90 s empieza un fundido a negro de 0,5 s.
3. A los ~1,5 s se carga la escena siguiente: tras el nivel 3, el final; tras el 6,
   el menú principal.

La ceremonia dura lo mismo que antes de existir: en PULSO pararse mata, y este ya es
el momento más quieto del juego, no se puede alargar.

### 8.5 El guardado

Un solo archivo JSON en el almacenamiento privado de la aplicación
(`user://progreso.json`). Contiene:

| Campo | Contenido |
|---|---|
| `max_nivel` | El nivel más alto alcanzado |
| `tiempos` | El mejor tiempo de cada nivel |
| `fragmentos` | El máximo de fragmentos recogidos en cada nivel |
| `muertes` | Contador total de muertes |
| `opciones` | Ajustes: `cerco_fijo`, `asistencia`, `vibracion`, y `teclas` (solo las acciones reasignadas, como `{"saltar": ["k32", "f75", "f87"]}`) |

Reglas del guardado:

- **Se escribe al completar un nivel y al salir al menú**, no al morir: morir es un
  momento crítico y no toca hacer entrada/salida a disco.
- **Un tiempo peor no pisa al mejor**, y los fragmentos guardan el máximo.
- **Si el archivo está corrupto** (por ejemplo, el móvil se quedó sin batería a
  mitad de escritura), el juego empieza de cero en lugar de fallar.
- Los ajustes viven en el mismo archivo: un segundo archivo es un segundo archivo
  que se puede corromper.

El progreso se ve en la pantalla NIVELES (sección 8.6). Las balizas no se guardan:
un punto de control vive solo mientras dura el nivel.

---

### 8.6 La pantalla NIVELES

Con algún nivel pasado, JUGAR abre **NIVELES**: seis tarjetas en una fila, una por
nivel, y dos botones de historia.

| Elemento | Qué muestra | Cuándo está abierto |
|---|---|---|
| Niveles 1 a 6 | Número, nombre, mejor tiempo, par y los tres fragmentos (rombos llenos = recogidos) | Al llegar a ese nivel |
| Desde el principio | La intro, y de ahí el nivel 1 | Siempre |
| Ver el final | La cinemática del final, y de ahí el nivel 4 | Al pasar el nivel 3 |

Un tiempo **por debajo del par** sale en lima; por encima, en blanco: es lo único que
la pantalla «celebra». Lo cerrado sale apagado y con candado, y al intentar abrirlo
sacude la tarjeta y el pie dice qué falta («Completa el nivel 3 para abrirlo»).

El foco empieza en el **nivel más alto abierto**, que es a donde casi siempre se
vuelve: seguir es pulsar Intro. Se maneja como el menú:

- **Teclado:** flechas para moverse entre tarjetas y entre los botones de abajo,
  Intro para jugar, Esc para volver.
- **Ratón:** pasar por encima enfoca; clic izquierdo juega.
- **Dedo:** tocar enfoca y levantar sobre la misma tarjeta juega; tocar fuera del
  panel vuelve al menú. Todo lo que se toca mide al menos 46 px de alto.
- **Atrás de Android:** vuelve al menú.

Elegir un nivel entra en la cadena de siempre: desde el nivel 3, al terminarlo, sale
el final; desde el 4, el 5 y el 6; y al terminar el 6, el menú principal.

## 9. La interfaz

### 9.1 El menú principal

El menú tiene **cuatro opciones**: JUGAR, OPCIONES, CREDITOS y SALIR, y se maneja
igual con el **teclado**, con el **ratón** y con el **dedo**:

| | Elegir | Activar |
|---|---|---|
| Teclado | Flechas arriba y abajo | Intro (o Espacio) |
| Ratón | Pasar por encima | Clic izquierdo |
| Dedo | Poner el dedo en la fila | Levantarlo **sobre la misma fila** |

Con el dedo, si se arrastra fuera de la fila antes de levantarlo, no se activa nada:
es la forma de arrepentirse que tiene una pantalla táctil. Las filas miden **46 px**
de alto, la misma medida que las filas de la pausa, porque por debajo de eso no se
aciertan con el pulgar; la zona que responde es todo el ancho del panel y llega a la
mitad del hueco entre filas, así que un dedo que cae entre dos cuenta. La rueda del
ratón no hace nada, y el clic que Godot emula a partir de cada toque se ignora, para
que un toque cuente una sola vez.

- **JUGAR** la primera vez inicia la intro y de ahí el primer nivel. Con algún nivel
  ya pasado, abre la pantalla **NIVELES** (sección 8.6).
- **OPCIONES** abre la pantalla **CONTROLES**, donde se ven y se cambian las teclas
  (sección 4.4). Su cabecera recuerda que el volumen y la accesibilidad están en la pausa.
- **CREDITOS** muestra la autoría: «Diseño, arte y código: Jose Gpe Rico Moreno», con
  Godot Engine y Blender como herramientas.
- **SALIR** no se pulsa: **se mantiene 3 segundos**, con la tecla o con el dedo
  encima. Es una retención deliberada para que no se cierre el juego por accidente.
  Si el dedo se sale de la fila, se suelta, igual que levantar la tecla.

#### El fondo 3D vivo

Detrás del menú hay una **escena 3D de verdad**, no un dibujo: TSL-04, un anillo en
forma de toro y cinco placas de circuito a distintas profundidades, con paquetes de
datos que recorren el bus. La escena cuesta unos 92 dibujos por cuadro, con tope de
200. No hay sombras, resplandor de entorno ni reflejos, porque en GL Compatibility o
no existen o se pagan caros; el resplandor se consigue con materiales emisivos.

Se eligió 3D vivo en lugar de una hoja pre-renderizada por una razón de fondo: lo que
hace que algo se sienta tridimensional no es estar sombreado, es **responder**. Al
cambiar de opción, la cámara se desplaza (0,42 unidades por paso) y el paralaje entre
las placas cercanas y las lejanas solo se puede leer como distancia.

#### TSL-04 en el menú

El protagonista del menú es **el mismo modelo de Blender** que genera los sprites del
juego, exportado a un archivo `.glb` de 160 KB (unos 2.300 triángulos). No es una copia
hecha con primitivas, porque una copia se separaría del personaje real al tocar una
proporción en el generador. Se ilumina aparte del decorado, con tres luces propias
(clave lateral, relleno frío y borde) para que la esfera no salga quemada.

TSL-04 **mira la opción elegida**: la cabeza hace el 65 % del giro y los ojos completan
el resto, como se mira de verdad. Y cada opción tiene **su propia reacción**:

| Opción | Reacción |
|---|---|
| JUGAR | Dos brincos, y en cada aterrizaje se aplasta: ganas de salir corriendo |
| OPCIONES | Ladea la cabeza deprisa y la va enderezando: curiosidad |
| CREDITOS | Asiente dos veces, como quien lee una lista de nombres |
| SALIR | Se hunde y agacha la cabeza, y se recupera sola |

Al confirmar se repite la reacción de esa opción, más grande. Si pasan 7 segundos sin
tocar nada, TSL-04 levanta la vista para buscar al jugador. Pestañea cada 2,6 a 5,5
segundos y también al cambiar de opción.

Las reacciones son **curvas que se apagan solas**, no estados: no hay banderas que
puedan quedarse encendidas, y si el jugador cambia de opción a mitad de una reacción,
la nueva empieza de cero y el cuerpo llega a ella suavizado, sin tirones. Por
construcción, el personaje no puede quedarse «trabado» en una pose.

#### La despedida

Mantener SALIR 3 segundos activa una despedida de TSL-04. Deja de mirar al menú y
**busca al jugador**, **agacha la cabeza sin dejar de mirarle** (la cabeza baja y
los ojos suben solos), se ladea, se encoge un 16 %, se le cierran los párpados y su luz propia se apaga un 45 %. Y bajo el personaje escribe **«adios» en binario**, un
byte por letra, bit a bit, como si lo estuviera transmitiendo; en cuanto un byte se
completa, aparece debajo su letra. Los unos van encendidos y los ceros apagados: el
mismo lenguaje que las celdas de carga del HUD.

Termina de escribirse al 92 % de la retención, no al 100 %, para que se llegue a leer
la última letra antes de cerrarse el juego. Si se suelta el botón, todo se deshace.

### 9.2 El HUD

El HUD es **un único control** que se pinta en una pasada. Lo que se ve:

- **Barra de carga** (esquina superior izquierda, 168 × 14 px) con la cifra de
  segundos restantes a su derecha. Un «fantasma» muestra la pérdida reciente, y
  distingue la fuga constante (el consumo de 1,6 %/s) de la maniobra (un impulso, un
  pulso).
- **Fragmentos** como rombos (◆◇◇), no como «0/3»: se cuentan de un vistazo. Cada
  rombo hace un pequeño «pop» al recogerse.
- **Cronómetro** en la esquina derecha con el formato «tiempo / par», con cifras de
  ancho fijo para que no bailen. Al superar el par, el cronómetro se apaga una vez; no
  se pone en rojo, porque nada del HUD debe sentirse como castigo añadido.
- **Título del nivel**, que aparece al entrar, se mantiene 2,2 s y se desvanece en
  0,8 s en lugar de ocupar sitio para siempre.
- **Estado**, una línea breve que solo dice lo que hace falta ahora: «busca la
  terminal», «conectando…», «puerta abierta  ->  a la salida», «salida alcanzada»,
  y durante 1,6 s tras pisar una baliza, «punto de control».
- **Chevron indicador**, una flecha en el borde que apunta al objetivo actual (primero
  la terminal, luego la salida) y se vuelve más opaco cuanto más cerca está (de 0,25 a 600 px de distancia a 0,70 a 200 px).

#### El cerco: urgencia sin mirar

La cámara está clavada al personaje, así que el ojo del jugador está **siempre en el
centro de la pantalla** y su visión periférica es el marco del viewport. Por eso el
aviso de poca carga no es un piloto en una esquina sino un **cerco en el borde** de
la pantalla, y la urgencia se codifica en **frecuencia**, que se lee sin enfocar y sin
distinguir colores.

| Carga | Color | Grosor | Latido |
|---|---|---|---|
| Más de 40 % | Cian | 2 px | Estático (opacidad 0,10) |
| 25 – 40 % | Ámbar | 3 px | Latido suave (0,13 – 0,28) |
| 10 – 25 % | Rojo | 4 px | Latido medio (0,19 – 0,42) |
| Menos de 10 % | Rojo | 6 px | Latido fuerte (0,31 – 0,70) |

La frecuencia del latido va de 0,4 Hz a un **máximo de 2,6 Hz**, por debajo del
umbral fotosensible de unos 3 Hz. Es un tope duro: nada del HUD lo supera. El latido
sube en 0,06 s y cae el resto del periodo; es un latido, no una respiración, porque
una senoide no se lee como urgencia.

El **cuadro central de 120 px es intocable**: ahí está el personaje, y nada del HUD se
dibuja encima.

### 9.3 El menú de pausa

Se abre con Esc, con el botón de pausa táctil o con el botón atrás de Android, y
**congela el árbol del juego de verdad**: devuelve al jugador exactamente al mismo
sitio. Antes, la tecla de pausa te sacaba al menú y perdías el nivel. Al abrirse
oculta el HUD y los mandos, para que no se lea mejor el cronómetro que las opciones.

Tiene **seis filas**:

| Fila | Tipo | Alto | Contenido |
|---|---|---|---|
| Continuar | Acción | 46 px | Cierra la pausa |
| Volumen efectos | Volumen | 30 px | 8 celdas |
| Volumen música | Volumen | 30 px | 8 celdas |
| Accesibilidad | Interruptores | 30 px | Tres chips: Cerco fijo, Asistencia, Vibración |
| Reiniciar nivel | Destructiva | 46 px | Pide confirmación |
| Salir al menú | Destructiva | 46 px | Pide confirmación |

Decisiones de diseño que salieron de medir el menú que había:

- **Las filas de acción miden 46 px**, porque por debajo no se aciertan con el
  pulgar. Los ajustes pueden ser de 30 px: se tocan sin prisa.
- **El volumen son 8 celdas discretas, no un deslizador.** Con el pulgar se acierta
  una celda; arrastrar obliga a mirar el valor. **Cero celdas es el silencio**, así
  que no hace falta una fila propia para silenciar. Tocar a la izquierda de la primera
  celda apaga.
- **Los tres interruptores van en una sola fila**, no en una página nueva: el menú ya
  ocupa 302 de 360 px de alto. Encendido es relleno cian y apagado es solo contorno,
  el mismo vocabulario que las celdas de volumen. Izquierda y derecha mueven el foco
  sin cambiar nada: si lo cambiaran, recorrer la fila con el mando iría activando y
  desactivando todo lo que tocara.
- **Las dos filas destructivas piden dos toques** (la confirmación dura 2 s) y llevan
  24 px de aire y una barra roja delante. Antes estaban a 12 px de «Continuar».
- **Al reanudar**, el velo cae en 0,10 s y un pulso cian recorre el borde en 0,18 s
  *antes* de descongelar el juego: en un juego donde se tienen 0,35 s, volver de golpe
  desorienta.
- Al reiniciar o salir **no hay ceremonia**: cambiar de escena con el árbol pausado
  deja el nivel siguiente congelado y sin forma de salir.

Valores por defecto de los interruptores: cerco fijo apagado, asistencia apagada,
vibración **encendida**.

---

## 10. Sonido y música

### 10.1 La regla de diseño

> El audio **refuerza**, nunca **informa** de algo que no se vea.

Mucha gente juega en silencio (en el metro, por ejemplo), así que ninguna información
crítica vive solo en el sonido. Los peligros avisan con luz y movimiento. El sonido
añade: confirma un salto, sube de tono con cada fragmento, subraya una muerte.

### 10.2 Los efectos

Hay **nueve efectos**, todos **sintetizados por script** (`tsl04/build_sonido.py`) sin
una sola muestra de ningún sitio: ondas cuadradas, barridos y ruido digital, porque
el juego transcurre dentro de una computadora. Ninguno satura (pico de 0,72).

| Efecto | Cuándo suena |
|---|---|
| salto | Al saltar, con un tono que varía al azar (repetido idéntico cansa en dos minutos) |
| aterrizaje | Al tocar el suelo |
| impulso | Al impulsarse |
| muerte | Al morir |
| terminal | Al accionar una terminal |
| fragmento | Al recoger un fragmento; cada uno suena más agudo que el anterior |
| puerta | Al abrirse la puerta |
| aviso | Al avisar un peligro |
| portal | Al alcanzar la salida (dura 0,90 s) |

Se reproducen en un banco de **8 voces** simultáneas. Siguen sonando con el árbol
pausado, porque la congelación de la muerte detiene el tiempo del juego y, si no, el
sonido de la muerte no se oiría.

### 10.3 Los volúmenes

Hay dos volúmenes independientes, para que quien juega en el metro pueda bajar la
música sin perder la señal de los efectos: efectos a 0,80 y música a 0,55 por defecto.
La música va por un **bus propio** y se hunde **12 dB** al pausar en lugar de cortarse.

### 10.4 «Circuito»: el tema del juego

La música de los niveles es un único tema, «circuito», también sintetizado
(`tsl04/build_musica.py`). Dura **64 segundos** (40 compases a 150 BPM) y está compuesto
por **cinco capas**:

1. El **latido de negra**.
2. Un **arpegio de semicorcheas** que son los paquetes de datos del fondo, hechos sonido.
3. Un **zumbido de máquina**.
4. Un **tic de reloj**.
5. Un **barrido lento**.

Tres decisiones que no son de gusto:

- **Pulso constante de negra a 150 BPM.** En PULSO pararse mata, así que la música no
  puede invitar a quedarse quieto: ni silencios largos ni respiraciones. El juego no
  las da.
- **El bucle cierra por construcción, no con fundidos.** Las voces con notas llevan
  envolventes que acaban en cero, y las sostenidas se afinan a múltiplos exactos de
  1/64 s para completar un número entero de ciclos. El empalme medido es de 0,00001: sin
  esto se oiría un clic en cada vuelta.
- **64 segundos y no 25.** Con 25 s, el bucle daba 140 vueltas en una hora de juego. Va a
  22.050 Hz (son ondas cuadradas, casi todo por debajo de 4 kHz) y comprimido, de modo
  que ocupa 2,7 MB en disco y mucho menos en el paquete.

### 10.5 «Libre»: el tema del final

Es el contrapunto de «circuito». Está en **Do mayor**, la relativa mayor de La menor
en que está «circuito»: **las mismas notas, pero resolviendo hacia arriba**. Va a 100
BPM y tiene el latido **una vez por compás** en lugar de en cada negra: en el juego, el
pulso constante dice «no pares»; aquí ya puede parar. No hay tic de reloj ni arpegio de
datos. El colchón es de ondas triangulares y una caja de música que no pasa de 880 Hz,
por debajo de los 1.046 Hz del sonido de aviso de peligro.

Dura 38,4 segundos (16 compases), más que el final entero (36,3 s): no llega a dar la
vuelta. Solo suena durante la cinemática del final.

### 10.6 Reglas de no solapado

Dos músicas **no pueden sonar a la vez por construcción**: hay un único reproductor
de música. Lo que había que evitar eran los cortes, y se garantiza así:

- Pedir un tema que ya suena **no lo reinicia**: entrar en un nivel no corta la música
  del menú.
- Parar la música admite un fundido. Hacia el final, «circuito» se apaga con el fundido
  a negro en su mismo medio segundo.
- Los temas se registran en una lista explícita, no escaneando el directorio: al
  exportar, los archivos de origen no viajan en el paquete y el juego se quedaría mudo
  justo en el móvil.

---

## 11. Accesibilidad

PULSO pide precisión y no perdona, lo que lo hace difícil para algunos jugadores. La
accesibilidad no se resuelve con un «modo fácil» genérico sino con tres ajustes
específicos y varias decisiones de base.

### 11.1 Los tres ajustes

Están agrupados en la fila «Accesibilidad» del menú de pausa y se guardan:

| Ajuste | Por defecto | Qué hace |
|---|---|---|
| **Cerco fijo** | Apagado | Sustituye el latido del cerco de poca carga por un grosor y un color constantes, para quien no tolera el parpadeo |
| **Asistencia** | Apagado | Alarga el retardo de la estela de 0,35 a 0,70 s |
| **Vibración** | Encendido | Vibración de 70 ms al morir en dispositivos con motor de vibración |

### 11.2 Decisiones de base

- **Paleta validada para daltonismo.** Se comprobó simulando protanopia y
  deuteranopia (método de Viénot, 1999) sobre los pares de colores del juego, y todos
  se distinguen:

  | Par | Normal | Protanopia | Deuteranopia |
  |---|---|---|---|
  | rojo vs lima | 0,796 | 0,748 | 0,538 |
  | rojo vs ámbar | 0,526 | 0,494 | 0,368 |
  | rojo vs cian | 1,324 | 0,996 | 1,014 |

  Aguanta porque el **rojo es mucho más oscuro** que el resto (luminancia 0,238 frente a
  0,763 del lima): se distinguen por claridad aunque falle el tono, hasta en escala de
  grises. Conviene no tocar esas luminancias.
- **Seguridad fotosensible.** Ningún parpadeo del HUD pasa de 2,6 Hz.
- **Se juega en silencio**, como se explicó en la sección 10.
- **Mandos táctiles grandes** y multitáctil real, con el botón de pausa deliberadamente
  separado del resto.
- **Tiempos de gracia generosos**: 1,1 s de invulnerabilidad al reaparecer y 0,85 s de
  pausa tras morir.
- **Sin castigos añadidos**: no hay vidas limitadas, y el cronómetro nunca se pone en
  rojo.

---

## 12. Arte y producción

### 12.1 La doctrina: nada se modela a mano

Todo el arte se genera con **scripts de Python sobre Blender 5.2.1**, que viven en la
carpeta `tsl04/` junto al proyecto. Nada se modeló a mano, de modo que cualquier cambio
es reproducible: se edita el script y se regenera.

| Script | Qué genera |
|---|---|
| `build_tsl04.py` | TSL-04: modelo, 12 animaciones (hojas de sprites y recurso de Godot) y el `.glb` del menú |
| `build_elementos.py` | Los objetos del nivel: bloques, peligros, terminal, puerta, portal, anclaje |
| `build_estela.py` | La estela, con núcleo blanco y halo de color |
| `build_fondo.py` | El fondo animado: 16 cuadros a 8 fps con paquetes de datos recorriendo los buses y LEDs parpadeando. Cierra el bucle exacto |
| `disena_niveles.py` | Los seis niveles y sus tres verificadores (alcance, holguras, techos bajos) |
| `grandes.py` | Las piezas de los niveles 5 y 6 (calles, escaleras, balizas), que lee `disena_niveles.py` |
| `laminas.py` / `dibujo.py` | Las láminas SVG de la intro y el final |
| `build_sonido.py` | Los nueve efectos de sonido |
| `build_musica.py` | Los dos temas musicales |
| `rayos.py` | Los rayos, con un modelo de ruptura dieléctrica; se ejecuta sin Blender |

El generador de rayos merece mención: sus pasos se mantienen dentro de ±30° el 54 % de
las veces (la literatura dice «poco más del 50 %»), con ramas a 20–45°, un canal que se
afila y una tensión que tira hacia el electrodo, sin la cual el paseo aleatorio se
enrosca.

### 12.2 Por qué el personaje parecía plano

Durante la producción, TSL-04 se veía plano. La causa no era la curva de tono sino la
**exposición**: con las luces de entonces, el canal azul estaba clavado en 255 en el
55 % del cuerpo y el verde en el 49 %. En más de la mitad del personaje solo quedaba
vivo el canal rojo, que en la paleta cian vale 0,13 de 1,00: toda la forma se contaba
con un tercio de la información. Las correcciones fueron tres, todas de exposición:

1. La luz principal estaba casi frontal, y la luz frontal aplana por definición. Se llevó
   a un lado y se bajó de 340 W a 190 W.
2. Las luces de borde sumaban 820 W contra una principal de 340: eran 2,4 veces la
   luz principal, cuando funciona al revés (el borde describe la silueta, que ya se lee
   sola; la luz principal describe la forma).
3. La emisión propia del cuerpo se bajó de 0,32 a 0,07.

Tras ello, el canal azul clavado pasó del 54,6 % al 17,1 % del cuerpo. Se probaron
además varios mapeadores de tono (AgX, Filmic y Khronos PBR Neutral) y se descartaron
todos: AgX deja la saturación en 0,200 frente a 0,526 y el cian se vuelve gris lechoso.

### 12.3 Trampas del proceso, anotadas

- **El resplandor de EEVEE no se guarda en un PNG con fondo transparente.** El brillo
  tiene que ser geometría: tubos concéntricos separados en profundidad.
- **Godot sirve la textura importada en caché.** Al reemplazar un PNG hay que borrar
  `.godot/imported/` y reimportar, o el juego sigue mostrando el arte viejo.
- **Godot en modo headless no importa archivos nuevos** automáticamente: hay que lanzar
  una importación explícita.

---

## 13. Anexo técnico

### 13.1 Arquitectura

El proyecto tiene **cuatro autoloads** (singletons cargados siempre):

| Autoload | Función |
|---|---|
| `Efectos` | Efectos de pantalla: congelación, destello, sacudida, aberración, chispas, vibración |
| `Guardado` | Progreso y ajustes persistentes en JSON |
| `Audio` | Efectos de sonido, música, volúmenes y bus |
| `Teclas` | Las teclas del jugador: aplica, valida y guarda la reasignación. Va después de `Guardado` |

Los nodos principales:

- **`nivel.gd`**: orquesta cada nivel: une terminal, puerta y portal, reinicia al morir,
  encadena con el siguiente nivel (tras el último, el menú) y alimenta al HUD. Con
  una baliza pisada, al morir reaparece en ella en vez de reiniciar.
- **`jugador.gd`**: todo el movimiento, la carga y la muerte de TSL-04.
- **`rejilla_estela.gd`**: la estela.
- **`peligro.gd`**: clase base de todos los peligros.
- **`hud.gd`, `pausa.gd`, `menu.gd`, `menu3d.gd`, `tactil.gd`**: la interfaz.
- **`cine.gd`**: las dos cinemáticas.
- **`baliza.gd`**: los puntos de control de los niveles 5 y 6.

### 13.2 Decisiones técnicas recurrentes

- **La interfaz se pinta a mano** con `_draw()` sobre nodos `Control`, sin nodos de
  botón ni temas. El HUD entero es un solo control. Sin `Tween`: en un móvil con GL
  Compatibility, crear y destruir un `Tween` por elemento es un goteo de basura por
  cuadro; el estado de animación son floats avanzados en `_process`.
- **Todo anclado, no colocado a mano.** Con el estiramiento `expand`, el ancho pasa de
  640 a 780 px en móviles 19,5:9 y 20:9; lo colocado por desplazamientos fijos se queda
  a media pantalla.
- **No hay `z_index` en todo el proyecto**: el orden de dibujo es el del árbol de
  nodos.
- **La escena 3D del menú va en un `CanvasLayer` con `layer = -1`**, no colgada del
  control: un `CanvasItem` se dibuja antes que sus hijos, y colgada ahí tapar todo lo que
  pinta `_draw()`.
- **Las pruebas no usan el reloj de pared** donde pueden evitarlo: la estela y la gracia
  usan relojes propios o del motor.
- **Android: la fuente del proyecto no tiene la flecha Unicode**, por lo que los textos
  usan «->» en lugar de «→»: en macOS el sistema presta el glifo, pero en Android
  saldría un cuadrado vacío.

### 13.3 Efectos de pantalla

El autoload `Efectos` vive en una capa 100 y sigue activo durante la congelación. Las
cifras de diseño de la muerte: congelación de 0,08 s, sacudida de 3 px, aberración
cromática de 0,2 s, 24 chispas con vida de 0,55 s. Las chispas usan **un único emisor
reutilizado**: nada se instancia durante la partida.

### 13.4 Rendimiento

El juego está pensado para móvil de gama media. Presupuestos medidos:

- Escena de menú completa: unos 92 dibujos por cuadro (tope de prueba: 200).
- Niveles: la prueba de presupuesto de dibujo mide 13 dibujos frente a un tope de 60.
- Fondo animado: hoja de 16 cuadros a 8 fps, 2,4 MB.
- Sonido: 4,6 MB en disco; las dos músicas se comprimen al exportar.

### 13.5 Batería de pruebas

El proyecto tiene **45 escenas** en `prueba/` (algunas son pruebas, otras herramientas
de captura). Se lanzan sin ventana:

```bash
Godot --headless --path . prueba/muerte.tscn
```

Cada prueba imprime «FALLOS: N». Las más relevantes:

| Prueba | Qué protege |
|---|---|
| `ui` | Menú 3D, piezas de TSL-04, mirada, reacciones, despedida en binario y cinemática |
| `final` | El paso nivel 3 → final → nivel 4 con cambios de escena reales: tiempos, audio y escenas |
| `ajustes` | La asistencia idéntica apagada, la rejilla viva, la vibración y la fila de pausa |
| `sombra` | Sombra en el suelo, monótona con la altura, oculta sobre el vacío |
| `estela` | Que el reloj de la estela no sea el de pared |
| `grandes` | Los niveles 5 y 6: estructura, balizas, que el nivel 1 sigue reiniciándose entero, y bots que llegan al portal |
| `selector` | La pantalla NIVELES con sus seis tarjetas: tabla igual a las escenas, teclado, dedo, candados |
| `pared` | Adherencia, deslizamiento y altura del salto de pared |
| `tactil` | Multitáctil, zonas y pérdida de foco |
| `pausa` | Congelación, retorno al sitio y botón atrás |
| `guardado` | Progreso, mejor marca y archivo corrupto |
| `aparicion` | Que el jugador nazca donde toca en todos los niveles |

El estado a 11 de octubre de 2026: **27 de las 28 pruebas lanzadas en aquella revisión pasaban sin fallos** (no se lanzaron `rend` ni las escenas de captura). La restante, `obst`, tiene un fallo conocido que es un artefacto de la
propia prueba: pega el dron de purga al jugador y salta directamente a «alerta» sin
pasar por «patrulla». El 20 de octubre, con los niveles 5 y 6, se volvieron a lanzar
`grandes`, `selector`, `aparicion`, `fondo` y `personajes`: las cinco, sin fallos.

Algunos fallos encontrados «sin buscarlos» por las pruebas, todos silenciosos, que
justifican su existencia:

1. **Una prueba colgada un día entero**: miraba propiedades que ya no existían y
   erraba en cada cuadro sin terminar nunca. Ahora toda prueba lleva guardia de tiempo.
2. **El fondo se iba a partir de x = 2.050 px**: un desplazamiento se aplicaba dos
   veces por una configuración doble, y el fondo derivaba al revés y tres veces más
   rápido.
3. **Pinchos y drones mal colocados en Runthedrun**: los bots de `prueba/grandes`
   aterrizaban sobre pinchos puestos justo después de un hueco y chocaban con drones
   colgados a 6 filas del suelo (sección 8.3).

Además, las pruebas que escriben el guardado lo hacen sobre el archivo real, por lo que
guardan una copia antes y la devuelven después; antes, pasar las pruebas borraba la
partida del jugador.

### 13.6 Estructura de carpetas

```
pulso-godot/
├── project.godot          configuración, mapa de entrada, autoloads
├── LEEME.md               diario técnico del proyecto
├── PRIVACIDAD.md          política de privacidad y formularios de Play
├── escenas/               menú, pausa, HUD, mandos, cinemáticas, jugador
│   ├── niveles/           los 6 niveles
│   └── obstaculos/        terminal, puerta, portal, balizas, peligros
├── scripts/               todo el código (30 scripts, unas 6.500 líneas)
├── arte/                  sprites, láminas, sonido, modelo 3D
│   ├── tsl04/             el personaje: hojas de animación y .glb
│   ├── elementos/         bloques y obstáculos
│   ├── estela/            las láminas de la estela
│   ├── fondo/             el fondo animado
│   ├── laminas/           las láminas de la intro y el final
│   └── sonido/            los efectos y las dos músicas
├── shaders/               aberración cromática
└── prueba/                45 escenas de prueba y captura
```

---

## 14. Estado actual y hoja de ruta

### 14.1 Qué está hecho

- La mecánica completa: movimiento, impulso, adherencia, pulso, estela y carga.
- Seis tipos de peligro más terminal, puerta, portal, anclaje y balizas.
- Seis niveles hechos a mano, los dos últimos grandes y con balizas.
- Intro y final feliz, con música propia y transiciones medidas.
- Menú principal 3D con TSL-04 reactivo y despedida.
- HUD de móvil con cerco de urgencia.
- Menú de pausa con volúmenes, accesibilidad y confirmaciones.
- Controles táctiles multitáctil.
- Guardado resistente a corrupción.
- Nueve efectos y dos temas musicales sintetizados.
- Modo asistencia, cerco fijo y vibración.
- Recursos gráficos de la ficha de Google Play (icono, gráfico destacado y seis
  capturas) y un borrador de política de privacidad.

### 14.2 Lo que existe a medias o no se usa todavía

Estas cosas están en el código pero no tienen efecto visible para el jugador:

- **Pruebas que escriben el guardado real.** Las que pasan por la salida de un nivel
  escriben en el archivo de progreso de verdad; todas copian el archivo antes y lo
  devuelven al acabar. Antes de que lo hicieran todas, dejaron récords imposibles en
  el guardado de desarrollo (0,4 s en el nivel 2), que se borraron el 13 de octubre
  de 2026.
- **El grupo `sin_estela`** (plataformas sobre las que no se deja estela) está
  soportado por el código del jugador, pero ninguna escena tiene plataformas de ese
  grupo.

- **La silueta de TSL-04** es una esfera, y al girar sobre sí misma no se nota. Hay un
  diseño medido para arreglarlo (un anillo ecuatorial inclinado, una espiga y dos aletas
  traseras) que no se ha aplicado, porque cambia la identidad del personaje y esa
  decisión es del autor.
- **El script `scripts/cine_tomas.gd`** es de una versión anterior de la intro y no lo
  usa ninguna escena. Las láminas SVG de `arte/laminas/`, en cambio, **sí se usan**
  (intro y final): borrarlas rompería las dos cinemáticas.
- **Los niveles 5 y 6 sin jugar a mano.** Los bots de `prueba/grandes` llegan al
  portal en los dos, lo que demuestra que se pueden pasar, pero no que sean justos ni
  divertidos para una persona. Nadie los ha jugado a mano todavía.

### 14.3 Para publicar en Google Play

| Requisito | Estado |
|---|---|
| Controles táctiles | Hechos y probados |
| Guardado | Hecho |
| Menú de pausa y botón atrás | Hechos |
| Sonido | Hecho |
| Relación de aspecto | Resuelta con `expand` |
| **Preset de exportación Android** | **Escrito** (`export_presets.cfg`: AAB, arm64, solo permiso VIBRATE, iconos adaptativos). Para compilar faltan Java 17, el SDK de Android y las plantillas |
| Permisos de Android | Hará falta `VIBRATE`; **`INTERNET` no debe marcarse**, porque el juego no la necesita |
| Política de privacidad | Borrador en `PRIVACIDAD.md`, con huecos por rellenar |
| Formulario «Seguridad de los datos» | Respuestas sugeridas, a revisar |
| Cuestionario de clasificación (IARC) | Respuestas sugeridas |
| Público objetivo | **Decisión del autor:** si se marca un público menor de 13 años, la app entra en la Política de Familias de Google |
| Formato de entrega | AAB (Android App Bundle), 64 bits, API que Google exija |
| Firma | Keystore propio, a guardar con cuidado: si se pierde, no se puede actualizar la app |
| Cuenta de desarrollador | Pago único de 25 USD |
| Pruebas cerradas | Si la cuenta es personal y nueva, Google exige 12 probadores durante 14 días seguidos |
| Ficha de tienda | Icono 512 × 512, gráfico 1024 × 500 y seis capturas, ya hechos |

### 14.4 Privacidad: lo que se ha comprobado

Una auditoría del código confirmó que PULSO no contiene **ninguna llamada de red, ni
identificadores de dispositivo, ni anuncios, ni compras, ni analítica**, y que lo único
que escribe a disco es `user://progreso.json`, que no sale del teléfono. El archivo
contiene nivel máximo, tiempos, fragmentos, muertes y los tres ajustes: nada que
identifique a una persona.

### 14.5 Orden recomendado de lo que falta

1. Instalar las plantillas de exportación y el SDK de Android, exportar y probar en un
   teléfono real.
2. Arrancar cuanto antes los 12 probadores, porque son 14 días de reloj.
3. Revisar, rellenar y publicar la política de privacidad.
4. Decidir el público objetivo.
5. Jugar a mano los niveles 5 y 6, y ampliar el contenido hasta 15–20 niveles.
6. Decidir sobre la silueta del personaje.

---

## 15. Glosario

| Término | Significado |
|---|---|
| **Anclaje** | Punto de aparición del nivel; marca dónde reapareces |
| **Asistencia** | Modo de accesibilidad que alarga el retardo de la estela a 0,70 s |
| **Baliza** | Punto de control de los niveles 5 y 6: recarga a tope, fija dónde se reaparece y es toma de tierra |
| **Buffer** | Margen de 0,12 s durante el que un salto pulsado antes de aterrizar se recuerda |
| **Carga** | La estadística única del personaje: vida y reloj a la vez |
| **Celda** | Cuadro de 16 px de la rejilla de la estela |
| **Cerco** | Borde de pantalla que late para avisar de poca carga |
| **Coyote time** | Margen de 0,10 s para saltar tras dejar el borde de una plataforma |
| **ERROR 04** | El nombre con que la máquina clasifica a TSL-04 |
| **Fragmento** | Cristal coleccionable en forma de rombo; da 5 de carga |
| **Gracia** | Invulnerabilidad de 1,1 s al reaparecer |
| **Hervor** | Alternancia de dos dibujos casi idénticos cada 0,1 s en las láminas |
| **Impulso** | Arrancón horizontal de 0,18 s que no deja estela |
| **NIMBUS-9** | El centro de datos donde transcurre la historia |
| **Par** | Tiempo objetivo de un nivel, en segundos |
| **Peligro** | Todo lo rojo: lo que mata al contacto cuando está encendido |
| **Portal** | La salida del nivel; solo funciona con la puerta abierta |
| **Pulso** | Acción que borra toda la estela a cambio de 25 de carga |
| **Rejilla de estela** | La estructura de marcas de tiempo que implementa la estela |
| **Retardo** | Tiempo entre pisar una celda y que empiece a matar: 0,35 s (0,70 s con asistencia) |
| **Terminal** | El interruptor del nivel; es toma de tierra |
| **Toma de tierra** | Zona donde la estela no se enciende y se puede estar quieto |
| **Tramo** | Trozo de un nivel entre una baliza y la siguiente; cada uno empieza con la carga a tope |
| **TSL-04** | La protagonista: la cuarta celda de prueba de carga |

---

*Fin del documento. Para el detalle técnico de cada decisión y su historial, consultar
`LEEME.md`; para los formularios de publicación, `PRIVACIDAD.md`.*
