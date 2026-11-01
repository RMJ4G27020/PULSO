# PULSO — estado del proyecto

Plataformas 2.5D en **Godot 4.7** (renderizador GL Compatibility). El escenario es el
interior de una computadora enorme, y TSL-04 deja una estela eléctrica que lo mata si
la vuelve a pisar: correr es seguro, pararse no.

Última actualización: **20 de octubre de 2026**.

> **Para entender el juego de principio a fin** (historia, controles, mecánicas, modos,
> interfaz, sonido), lee [`PULSO_GUIA_DEL_JUEGO.md`](PULSO_GUIA_DEL_JUEGO.md). Este
> LEEME es el diario técnico.

> Al día de hoy ya hay **mandos táctiles, menú de pausa, guardado, sonido,
> HUD de móvil y seis niveles hechos a mano**, los dos últimos grandes y con
> balizas (puntos de control).
> Lo que queda para publicar está al final.

---

## Cómo abrirlo

```bash
open /Users/joserico/pulso/pulso-godot
```

Godot está en `/Users/joserico/Documents/Archivo_Organizado/05_Software/Aplicaciones/Godot.app`. La escena principal es
`escenas/MenuPrincipal.tscn`, que encadena intro → nivel 1 → 2 → 3 → **final** →
nivel 4 → 5 → 6 → menú principal.

## Controles

| Acción | Tecla |
|---|---|
| Mover | A / D o ← / → |
| Saltar | Espacio, W o ↑ |
| Impulso | Shift o J |
| **Accionar terminal** | **E** |
| Pulso de reinicio | Q |
| Reiniciar nivel | R |
| Pausa | Esc (fija: no se reasigna), o el botón atrás en Android |

En móvil no hace falta ninguna tecla: **joystick flotante** en la mitad izquierda
(nace donde pones el pulgar, no hay que buscarlo) y tres botones a la derecha.
No hay botón de accionar: **la terminal se activa sola** tras 0,45 s encima, que
es seguro porque es toma de tierra. La tecla E sigue disparándola al instante.

### El menú con el dedo, y el botón atrás

El menú principal **solo leía teclado**: en un teléfono no había forma de pulsar
JUGAR. Ahora se maneja con teclado, ratón y dedo (`scripts/menu.gd`):

- **Tocar una fila la elige** (TSL-04 la mira) y **levantar el dedo sobre ella la
  activa**. Si el dedo se va de la fila antes de levantarlo, no pasa nada: es como
  se arrepiente uno en una pantalla táctil.
- **SALIR se mantiene con el dedo** 3 s, igual que con la tecla, con la despedida
  de TSL-04 incluida. Si el dedo se sale de la fila, se suelta.
- **Filas de 46 px** (medían 25), la medida que ya se midió para la pausa. Para
  que quepan, el panel sube de 0,46 a 0,345 del alto; acaba en 343 de 360.
  La mirada de TSL-04 (`FILA_PRIMERA` y `FILA_PASO` en `menu3d.gd`) se
  recalculó con las filas nuevas, y `prueba/menu_tactil` comprueba que casan.
- Con **ratón**, pasar por encima elige, como en cualquier menú de PC. La rueda
  no hace nada.
- Un toque cuenta **una vez**: el clic que Godot emula del toque se ignora (el
  mismo fallo que tenía la pausa).
- La **intro** se salta tocando, y dice «Toca para saltar» con pantalla táctil.

**El botón atrás de Android** cerraba la aplicación desde cualquier pantalla:
`application/config/quit_on_go_back` vale `true` de fábrica y con él Godot sale
sin preguntar, aunque `nivel.gd` intentara abrir la pausa. Ahora está en `false`
y cada pantalla decide:

| Dónde | Atrás |
|---|---|
| Nivel | abre la pausa, o la cierra |
| Cinemática | la salta |
| CONTROLES o créditos | vuelve al menú |
| Menú | la 1.ª vez lleva a SALIR y avisa; la 2.ª, antes de 2 s, sale |

Salir pide dos pulsaciones por lo mismo que SALIR se mantiene: que un atrás sin
querer no cierre el juego.

**La revisión adversarial del menú táctil encontró 7 fallos más, todos arreglados
y con su prueba** (que falla con el código anterior):

- **Mandos táctiles pegados entre escenas** (ya pasaba antes): con el pulgar en el
  joystick al cruzar el portal, `mover_der` seguía pulsado en la escena siguiente,
  porque `Input.action_press` es global. En el nivel 4, TSL-04 corría sola.
  `tactil.gd` suelta todo también al salir del árbol (`NOTIFICATION_EXIT_TREE`).
- **Pausa durante la ceremonia de salida** (ya pasaba antes): abierta en el
  fundido quedaba debajo del negro, pantalla negra sin salida; y «Reiniciar» no
  servía, porque al cerrarla la salida seguía y cargaba el nivel siguiente. Ahora
  en esos 1,5 s no se abre: es el momento más quieto del juego.
- **Un solo dedo manda**, sea cual sea su número: en Android el `index` es del
  sistema, y con el pulgar aún apoyado al volver al menú, el que toca JUGAR es el 1.
- **La suelta siempre libera el dedo**, haya panel o no: si no, el dedo se quedaba
  «puesto» en SALIR y la retención contaba sola al volver.
- **Un toque cancelado por el sistema** (la palma, el botón de encendido, una
  llamada: `canceled = true`) no cuenta como levantar el dedo.
- **Perder el foco** con el dedo en SALIR lo suelta y vacía la retención.
- **TSL-04 mira a la fila correcta también en 4:3**: en una tablet el alto pasa
  de 360 a 480, así que el menú le **mide** las filas al cambiar de tamaño en vez
  de usar dos números fijos.

### Personajes: las otras tres celdas

La historia ya las tenía: cuatro celdas de prueba colgaban de los cables de
NIMBUS-9 y tres se habían apagado; en el final, al sol, «a su lado se
encendieron otras tres luces». Esas tres son **TSL-01, TSL-02 y TSL-03**, y se
eligen en la pantalla NIVELES, abajo, junto a Volver (`scripts/personajes.gd`).

| | Color | Ventaja | Coste | Despierta | Estado |
|---|---|---|---|---|---|
| TSL-04 | cian | — | — | siempre | ✅ |
| **TSL-01** | ámbar | estela que tarda 0,55 s en encenderse (más margen para dudar) y gasta 1,3 %/s de carga | el impulso cuesta 5 % en vez de 3 | al ver el final (pasar el nivel 3) | ✅ |
| **TSL-02** | violeta | 250 px/s, salto de 125 px, impulso cada 0,6 s | gasta 1,9 %/s: la carga dura 53 s en vez de 62 | al pasar el nivel 4 | ✅ |
| **TSL-03** | plata | trepa sin gastar carga y el pulso cuesta 15 en vez de 25 | el impulso tarda 1,4 s en volver (0,9 los demás) | con los 12 fragmentos | ✅ |

**La regla que no se rompe:** ningún personaje salta menos, corre menos ni cae
más deprisa que TSL-04. Los niveles se verificaron con su física
(`disena_niveles.py` y `grandes.py` usan las mismas constantes que
`Jugador.tscn`): con menos alcance aparecerían saltos imposibles. Por eso los
costes van por la carga y el impulso. `prueba/personajes`
lo comprueba para todos, junto con otras dos reglas que salieron de la revisión:
**cada uno tiene una pega que se siente** y **ninguno muere resbalando por una
pared** (una celda de 16 px se cruza en 16/`deslizar` s, y eso tiene que ser menos
que lo que tarda la estela en encenderse: con TSL-04, 0,348 s contra 0,35. Por eso
TSL-03 no puede ni resbalar más despacio ni tener la estela más nerviosa) y
**la carga a ritmo de par**: una terminal da 15 y los fragmentos son opcionales, así
que la carga de cada **tramo** no puede pasar de 115 %:
`par / tramos × (220 / velocidad) × consumo ≤ 115 %` en todos los niveles (con
2,4 %/s TSL-02 pedía 139 % en el nivel 3). Los tramos son uno más que las balizas
del nivel, porque cada baliza recarga a tope: los niveles 1 a 4 son un solo tramo,
Lasermania seis y Runthedrun cinco.

**Los bots** (`PULSO_PERSONAJE=<id>`) recorren los niveles 1 a 4 igual con los
cuatro. Los bots de ruta de los niveles 5 y 6 (`prueba/grandes`) corren con
TSL-04 sin asistencia; con los otros tres esos dos niveles no se han recorrido.

- La duración de la estela (3 s, 5 s en TSL-01) casi no se nota: correr o aterrizar
  sobre tu propia estela la vuelve a marcar, y solo importa al cruzarla en el aire
  o con el impulso. Por eso no cuenta como «coste» de ningún personaje.
- `PULSO_PERSONAJE` **fuerza** el personaje aunque la partida no lo tenga
  despierto (solo pide que tenga arte), para que un bot lanzado con él corra de
  verdad con ese. Los bots fijan TSL-04 y sin asistencia si no se les dice otro, y
  devuelven el archivo de guardado al salir.
- El personaje cambia los `@export` de `jugador.gd` y la estela (retardo,
  duración, color y láminas). La **asistencia dobla el retardo de cada uno**:
  con TSL-04, los 0,70 s de siempre; con TSL-01, 1,10.
- Uno elegido que deja de valer (cerrado, sin arte o que no existe) cae a
  TSL-04: el juego nunca se queda sin personaje.
- Las chispas de la muerte salen de su color.
- **Arte:** `build_tsl04.py --color ambar|violeta|plata` y `build_estela.py
  --color ambar|violeta|plata` (la paleta de cada una está en `PALETAS` de los dos
  scripts; con `--retrato` sale solo el retrato, en 3 s, para juzgar el color antes
  de renderizar las 12 animaciones, que son ~2 min por color). Las hojas de cada
  paleta van en su carpeta (`arte/tsl04/<color>/`, `arte/estela/<color>/`) y el
  retrato en `retrato_<color>.png`: antes el retrato ámbar habría pisado el cian,
  del que salen el icono y la ficha. Las cuatro son el mismo modelo con otro color:
  **no tienen silueta propia**, y eso es decisión del autor, no del generador.
- El retrato del selector se saca de la hoja de reposo sola (`tsl04_reposo.png`,
  200 KB), no del `SpriteFrames` entero: cargarlo decodificaba las doce hojas (~25 MB)
  para dibujar un cuadro, y en un móvil flojo se notaba al abrir NIVELES.
- **Pruebas:** las que miden números de TSL-04 (estela, asistencia, pared, sombra,
  muerte) lo fijan con `Personajes.forzado`, que vive solo en memoria; si
  escribieran el personaje en el guardado, le cambiarían la elección a quien juega.

La revisión de los personajes encontró 8 hallazgos. Los verificadores murieron
por el límite de uso, así que se comprobaron **leyendo el código**; 7 eran reales:

- **TSL-01 no tenía coste.** Su estela de 5 s casi nunca pega: correr o aterrizar
  sobre la propia estela la vuelve a marcar *antes* de comprobar si mata. Era
  TSL-04 con más margen y menos gasto. Ahora el impulso le cuesta 5 % (en vez de 3).
- **TSL-03 moría en cada pared.** Resbalar a 26 px/s tarda 0,615 s por celda de
  16 px, y su estela se encendía a los 0,28 s. Con TSL-04 es 0,348 contra 0,35, y
  ese margen de 2 ms es lo que hace jugable la pared. Ahora su coste es otro.
- **`PULSO_PERSONAJE` no forzaba:** `actual()` lo filtraba por el progreso y caía a
  TSL-04 sin decirlo, así que un bot lanzado con él sobre una partida nueva pasaba
  por «probado» sin haberlo sido. Ahora solo pide que tenga arte.
- **Los bots corrían con el personaje y la asistencia de quien juega.** Ahora
  fijan TSL-04 sin asistencia y devuelven el guardado.
- **Derecha en el personaje cambiaba y guardaba el personaje** cuando Volver está a
  su derecha. Ahora, desde el personaje, abajo lleva a Volver.
- **Un toque bajo el botón del personaje cerraba NIVELES** en pantallas de 360
  de alto (el panel acaba 11 px antes del borde). La fila de abajo llega ahora
  hasta el borde.
- **El retrato decodificaba las doce hojas** para dibujar un cuadro (ver arriba).
- No era un fallo, sino un comentario falso: la animación de encendido (4 cuadros)
  llega al último al 36 % del retardo, y no «justo al matar». Es un aviso por
  exceso y es igual con TSL-04; se corrigió el comentario, no el comportamiento.

Al construir TSL-02 salió otro: con 2,4 %/s la carga (100 + 15 de la terminal)
no alcanzaba ni a ritmo de par en el nivel 3 (139 %). Bajó a 1,9 %/s y
`prueba/personajes` lo comprueba para los cuatro.

### Elegir nivel: la pantalla NIVELES

El progreso se guardaba desde el principio (nivel máximo, mejor tiempo y
fragmentos por nivel) y **nada lo enseñaba**: JUGAR empezaba siempre por la intro
y el nivel 1, así que quien había llegado a la chimenea tenía que volver a pasar
tres niveles para verla. Ahora (`scripts/selector.gd`):

- **La primera vez, JUGAR sigue llevando a la intro.** Un selector con un solo
  nivel abierto es un paso de más.
- **Con algún nivel pasado, JUGAR abre NIVELES:** seis tarjetas en una fila, una
  por nivel, con nombre, mejor tiempo, par y rombos de fragmentos, y dos botones,
  «Desde el principio» (intro → nivel 1) y «Ver el final» (final → nivel 4).
- Abierto lo que ya se ha alcanzado; lo demás, con **candado**, y al intentarlo el
  pie dice qué falta. El final, al pasar el nivel 3.
- El foco empieza en el **nivel más alto abierto**: seguir es un Intro.
- Teclado, ratón y dedo, con las mismas reglas que el menú (un solo dedo, activar
  al levantar, el clic emulado ignorado). Tarjetas de 198 px y botones de 46.
- Bajo el par, el tiempo sale en **lima**.
- Un botón **Volver** de 46 px, al que también se llega bajando con las flechas.

La revisión adversarial encontró 6 fallos, arreglados y con su prueba:

- **«Ver el final» cortaba la música del menú en seco.** El final daba por hecho
  que llegaba en silencio, como desde el nivel 3. Ahora, si suena otra cosa,
  `cine.gd` la apaga en medio segundo y «libre» entra después, desde silencio.
- **Un doble toque en JUGAR jugaba el nivel de debajo** antes de que se vieran
  las tarjetas. Durante los 0,3 s de entrada no se aceptan toques.
- **La única salida táctil eran 11 px de borde** («toca fuera»). De ahí el botón
  Volver.
- El contorno rojo de un rechazo **saltaba a la tarjeta enfocada después**;
  ahora se queda en la rechazada.
- Subir desde los botones **volvía a la primera tarjeta** si se había llegado con
  el ratón o el dedo; ahora vuelve a la última enfocada, se llegue como se llegue.
- Con teclado, entre el menú y NIVELES había **un cuadro sin nada encima del 3D**;
  ahora se abre en el mismo cuadro.

La tabla de nombres y pares está copiada en el selector para no cargar seis
niveles enteros solo por dos campos; `prueba/selector` comprueba que casa con el
`titulo` y el `par` de cada `.tscn` y con el `ORDEN` de `nivel.gd`. Lleva un
cuarto campo, los **tramos** de carga (uno más que las balizas del nivel), que es
de donde `prueba/personajes` saca la regla de la carga por tramo.

> **Los récords del guardado de desarrollo no eran de nadie** (0,8 s, 0,4 s,
> 12,7 s y 12,4 s en los niveles 1 a 4): los escribieron pruebas en versiones
> anteriores, antes de que todas copiaran y devolvieran el archivo. Se borraron
> el 13 de octubre de 2026, solo los tiempos; nivel máximo, fragmentos, muertes
> y ajustes se quedaron como estaban.

### Cambiar las teclas

Menú principal → **OPCIONES** abre la pantalla **CONTROLES**
(`scripts/controles.gd`). Cada acción tiene hasta **3 teclas**, porque saltar ya
trae 3 de fábrica.

| Tecla | Qué hace |
|---|---|
| ↑ ↓ | cambiar de acción (la pausa se ve pero no recibe el foco) |
| ← → | elegir cuál de sus teclas, o el hueco vacío para añadir una |
| Intro | ponerse a escuchar: la siguiente tecla que pulses se asigna |
| Supr o Retroceso | quitar la tecla elegida (nunca la última) |
| Esc | cancelar la escucha, o volver al menú |

La escucha **se acaba sola a los 5 s** sin cambiar nada, y un clic también la
cancela: no puede quedarse colgada. Restaurar pide **dos pulsaciones**.

Lo que manda es `scripts/teclas.gd` (autoload `Teclas`, después de `Guardado`).
Tres promesas que se cumplen por construcción:

- **Ninguna acción se queda sin tecla.** Si pones en saltar la única tecla de
  pulso, se **intercambian**: pulso se queda con la que tenía ese hueco de
  saltar. Si no hay nada que darle a cambio (hueco vacío), se rechaza.
- **Ninguna tecla está en dos acciones.** Si se la quitas a una que tiene más,
  simplemente pasa de una a otra, y el pie lo dice en ámbar.
- **La pausa es Esc y no se reasigna.** Es la salida de emergencia. Además, una
  pausa con Espacio o Intro se abría y se cerraba sola: `nivel.gd` la abre en
  `_unhandled_input` y `pausa.gd`, que corre con el árbol parado, veía el mismo
  `ui_accept` en ese cuadro y elegía «Continuar».

Las teclas que pone el jugador van **por posición física**: si cambia la
distribución del teclado, la tecla sigue en el mismo sitio de la mano. En
pantalla se nombra con lo que pone **en su teclado** (en uno español, la Ñ y no
`;`). Se pueden asignar letras, cifras, signos, flechas, Shift, Ctrl, Alt, Intro, Tab,
F1–F12 y, del teclado numérico, `* / - +` e Intro. Es una **lista blanca**, así que
Esc, Cmd, los bloqueos (Mayús, Num, Despl), volumen, multimedia y Atrás quedan
fuera sin tener que conocerlas una a una. Dos exclusiones que salieron de la
revisión: **las cifras del numérico** (con Bloq Num apagado, Num 4, 6 y 8 mandan el
código de las flechas, y las flechas de fábrica van por código: Num 4 en pulso
sería pulso y mover a la izquierda a la vez) y **Ctrl en macOS** (Ctrl con las
flechas son atajos del sistema que el juego nunca recibe).

**Guardado:** en `opciones.teclas` del mismo `progreso.json`, solo las
acciones que difieren de fábrica, como texto (`"f75"` es la K por posición
física, `"k32"` Espacio por código; texto y no números porque JSON devuelve
todos los números como float). Lo ilegible se descarta y esa acción vuelve a
fábrica; una tecla repetida entre acciones devuelve **todo** a fábrica. Leer
nunca escribe: un guardado roto se ignora pero no se pisa.

**Un fallo que salió de aquí, y que ya existía:** en la pausa, la flecha arriba
es de `ui_up` y de `saltar`, y la pausa elegía con las dos. Subir de fila
**elegía la fila nueva** en el mismo cuadro: desde «Volumen música» subía el
volumen de efectos, y desde «Volumen efectos» llegaba a «Continuar» y la pausa
se cerraba sola. Ahora solo elige `ui_accept` (que de fábrica incluye Espacio),
y `prueba/pausa` lo vigila con la tecla de verdad: con el código anterior falla.

**Y otro de la revisión, más grave en un teléfono:** en la pausa **un toque contaba
dos veces**. Godot emula un clic de ratón a partir de cada toque
(`emulate_mouse_from_touch` vale `true` de fábrica) y después manda el propio
toque, y la pausa aceptaba los dos. Así, un solo toque en «Reiniciar nivel» pasaba
a «confirmar» y confirmaba en el acto, y los interruptores de accesibilidad se
encendían y apagaban a la vez: en el móvil parecían muertos. También la **rueda
del ratón** contaba como clic (dos muescas confirmaban). Ahora solo vale el clic
izquierdo de un ratón de verdad: el emulado (`device == DEVICE_ID_EMULATION`) se
ignora y vale el toque. Lo mismo en CONTROLES, donde dos muescas sobre Restaurar
borraban todas las teclas.

Una trampa de la prueba, no del juego: los toques que se mandan con
`Input.parse_input_event` entran por la **ventana**, así que hay que pasar el
punto de coordenadas del juego (640×360) a las de la ventana con
`get_viewport().get_final_transform()`. Sin eso la primera versión de la prueba
tocaba fuera de la fila, y pasaba o fallaba sin medir nada.

---

## Qué hay hecho

### La mecánica

- **La estela como rejilla de marcas de tiempo** (`rejilla_estela.gd`). Una celda de
  16 px guarda el instante en que se pisó; morir es restar dos números. El coste no
  crece con la longitud del recorrido. Se enciende a los 0,35 s, mata hasta los 3 s y
  parpadea los últimos 0,4 s.
- **Toma de tierra**: la terminal descarga el pulso, así que es el único sitio donde
  puedes pararte sin morir. Sin eso era imposible accionarla. En los niveles 5 y 6
  las balizas también lo son.
- **Movimiento**: 220 px/s, salto de 115 px, coyote time 0,10 s, buffer 0,12 s, salto
  de altura variable (soltar el botón lo corta al 45 %).
- **Impulso** de 0,18 s que no registra estela.
- **Carga** como reloj y vida a la vez.
- Terminal → puerta → portal, fragmentos, seis tipos de peligro y, en los niveles
  grandes, balizas (puntos de control).

### Los peligros, con física

- **Dron de purga**: guarda velocidad y solo puede cambiarla a 110 px/s². De ahí sale
  *solo* que se pase 5,7 px del extremo de la patrulla y que tarde en arrancar cuando
  te ve. Se ladea hacia donde acelera, porque un cuadricóptero no tiene otra forma de
  empujar de lado.
- **Torreta zapadora**: oscilador amortiguado (ω = 15,5 rad/s, ζ = 0,48). Se pasa un
  18 % al apuntar y se asienta en 0,53 s, justo dentro del medio segundo que dura el
  apuntado. Ese vaivén *es* el aviso.
- Láser, bloque pulsante, pinchos, portal, anclaje, puerta e interruptor.
- Todos vuelven a su pose de partida al morir (`reiniciar()`), y se apuntan solos al
  grupo `peligro` desde la clase base.

### Móvil: mandos, pausa y guardado

- **`tactil.gd`** — multitáctil de verdad: se mueve con un pulgar mientras se
  salta con el otro, y soltar uno no suelta el otro. Al perder el foco (entra
  una llamada) se suelta todo, o el personaje sigue corriendo solo al volver.
  Los botones ganan sobre la zona de movimiento, para que un pulgar grande en
  el borde no mueva en vez de saltar. Solo aparecen si hay pantalla táctil.
- **`pausa.gd`** — congela el árbol de verdad y te devuelve al mismo sitio.
  Antes la tecla de pausa te echaba al menú y perdías el nivel. El botón atrás
  de Android pausa en vez de cerrar la aplicación.
- **`guardado.gd`** — un JSON en `user://`. Guarda nivel máximo, mejor tiempo,
  fragmentos y muertes. Un tiempo peor no pisa al mejor. Si el archivo se
  corrompe a medias (el móvil se queda sin batería), empieza de cero en vez de
  reventar. Morir NO escribe a disco: se vuelca al completar nivel o al salir.

### El sonido

Nueve efectos **sintetizados por script** (`../tsl04/build_sonido.py`), sin
muestras de ningún sitio: ondas cuadradas, barridos y ruido digital, porque el
juego pasa dentro de una computadora. Ninguno satura (pico 0,72).

La regla de diseño: **el audio refuerza, nunca informa de algo que no se vea.**
Mucha gente juega en silencio, así que un peligro que solo avisara con sonido
sería injusto. Los peligros ya avisan con luz y movimiento.

Detalles que se notan: el salto varía de tono al azar (repetido idéntico cansa
en dos minutos) y cada fragmento suena un tono más agudo que el anterior. Los
efectos siguen sonando con el árbol pausado, porque la muerte congela el tiempo.

#### La música

Un tema, **«circuito»**, también sintetizado (`../tsl04/build_musica.py`). Cinco
capas: el latido de negra, un arpegio de semicorcheas que son los paquetes de
datos del fondo en sonido, un zumbido de máquina, un tic de reloj y un barrido
lento. Va por un **bus propio**, así que su volumen se ajusta sin tocar los
efectos, y **se hunde 12 dB al pausar** en vez de cortarse.

Tres decisiones que no son de gusto:

- **Pulso constante de negra a 150 BPM.** En PULSO pararse mata, así que la
  música no puede invitar a quedarse quieto. Ni silencios largos ni
  respiraciones: el juego no te las da.
- **El bucle cierra por construcción, no con fundidos.** El juego pone
  `loop_begin = 0` y `loop_end` al final, así que la onda salta del último
  sample al primero. Las voces con notas llevan envolvente que acaba en cero, y
  las **sostenidas se afinan a múltiplos exactos de 1/64 s** para que completen
  un número entero de ciclos. Empalme medido: **0,00001**. Sin eso se oiría un
  clic en cada vuelta, para siempre.
- **64 s y no 25.** Con 25 s el bucle daba 140 vueltas en una hora de juego. La
  duración no sale gratis, así que va a **22.050 Hz** (son ondas cuadradas, casi
  todo por debajo de 4 kHz) y con `compress/mode=2`: 2,7 MB en disco, un cuarto
  de eso en el paquete.

No existía: la fontanería estaba entera (bus, reproductor, atenuación) y el tema
no, y la prueba pasaba igual porque solo comprobaba la fontanería. Incluía
literalmente «pedir un tema inexistente no revienta».

### El HUD

Rehecho para móvil. Lo que había era una línea de texto que ya se cortaba a
640 px, con posiciones absolutas que se descolgaban al ensanchar el viewport.

- Todo **anclado**, no colocado a mano: con `expand` el ancho pasa de 640 a 780
  y lo que esté por offsets se queda a media pantalla. Verificado en los dos.
- Los fragmentos son **rombos** (◆◇◇), no «0/3»: se cuentan de un vistazo.
- El tiempo va con cifras de ancho fijo, o el número da saltitos al contar.
- El título saluda y **se desvanece** a los 2,2 s en vez de ocupar sitio siempre.
- Ya no dice «PULSA E». Decirlo era un fallo: desde que la terminal se acciona
  sola, esa tecla no hace falta.

### El menú, con 3D vivo

Detrás del menú hay una **escena 3D de verdad**, no un dibujo: TSL-04, un anillo
de toro y cinco placas de circuito a distintas profundidades, con paquetes de
datos recorriendo el bus. `scripts/menu3d.gd`.

El decorado son **primitivas de Godot construidas por código**, así que no cuesta
ni un byte de paquete.

#### El protagonista está en el menú, y es el modelo de Blender

Aquí había una **esfera azul lisa**: en la pantalla que presenta el juego no
aparecía el personaje por ningún lado. Lo que hace reconocible a TSL-04 no es el
color, es la **cara**.

Lo que se carga es `arte/tsl04/tsl04.glb`, **el mismo modelo que renderiza los
sprites del juego**, exportado con `build_tsl04.py --glb`. No una copia hecha con
primitivas: una copia se separa del personaje de verdad en cuanto se toque una
proporción en el generador, y además el modelo trae ya la boca, el rubor y los
brillos de los ojos, que son lo que lo hace reconocible a tamaño de icono.

Se exporta **solo la pose de reposo**, sin animación y sin las piezas que solo
salen al morir (los ojos en X y las chispas). Sin el `Subdivision` del cuerpo:
la esfera base es de 48×24 y en un menú no se distingue, pero el modelo pasa de
~19.000 triángulos a ~2.300.

**TSL-04 se ilumina aparte del decorado**, con su propio juego de luces y su
capa de visibilidad (`light_cull_mask`). No es un capricho: el decorado son
placas planas y grandes que piden una clave fuerte, y esa misma clave sobre una
esfera brillante le comía media cabeza. Sus tres luces llevan las proporciones
que ya se midieron para los sprites: clave lateral, relleno frío a un tercio, y
borde **por debajo** de la clave. Y el especular de la clave va bajo (0,28),
porque en Blender ese brillo lo da un área de 1,2 m y una luz direccional lo
deja como una quemadura blanca del tamaño de una moneda.

#### Que mire, y que conteste

TSL-04 **mira a la opción que estás eligiendo**. El panel es una capa 2D y no
tiene sitio en el mundo, así que se calcula el punto que la cámara ve justo ahí y
se mira a ese punto. La **cabeza solo hace el 65%** del giro y los ojos completan
el resto, que es como se mira de verdad: a 100% la cara se giraba 42 grados y el
jugador le veía el perfil.

Y **cada opción tiene su propia reacción**:

| Opción | Qué hace |
|---|---|
| JUGAR | dos brincos, y en cada aterrizaje se aplasta: ganas de salir corriendo |
| OPCIONES | ladea la cabeza deprisa y la va enderezando: curiosidad |
| CREDITOS | asiente dos veces, como quien lee una lista de nombres |
| SALIR | se hunde y agacha la cabeza, y se recupera sola |

#### La despedida

**SALIR no se pulsa, se mantiene 3 s.** Ese hueco es el único sitio del menú
donde el jugador está haciendo algo largo y todavía puede arrepentirse, así que
TSL-04 lo usa para despedirse:

- Deja de mirar al menú y **te busca a ti**.
- **Agacha la cabeza sin dejar de mirarte.** La cabeza baja y los ojos suben
  solos, porque el punto que mira sigue siendo la cámara. Esa cara no está
  dibujada en ningún sitio: sale de las dos cosas juntas.
- Ladea, se encoge un 16 %, le pesan los párpados y **se va apagando** — su luz
  propia baja al 55 %. En una máquina que funciona con carga, eso es despedirse.
- Y **dice «adios» en binario**, un byte por letra, saliendo bit a bit como si
  lo estuviera transmitiendo. El último bit parpadea porque es el que se está
  escribiendo, y en cuanto un byte se completa aparece debajo la letra que dice,
  para que se lea aunque no sepas binario. Los unos van encendidos y los ceros
  apagados, el mismo idioma que las celdas de carga del HUD.

Termina de escribirse al **92 % de la retención, no al 100 %**: si acabara justo
al cerrarse el juego, nadie llegaría a leer la última letra.

`prueba/ui` **descodifica los bits y comprueba que ponen «adios»**. Un bit mal
puesto ahí no se ve a ojo, pero la despedida diría otra cosa.

Antes de esto negaba con la cabeza, y se quitó: un «no» rápido se lee como
**enfado**, y encima el suavizado de la pose (11/s) se comía el gesto, que se
quedaba en 0,09 rad. Triste y quieta se lee mucho mejor que agitada.

Al confirmar se repite la reacción de esa opción **más grande**: es la diferencia
entre «te he oído» y «voy». Y si pasas un rato sin tocar nada, levanta la vista a
buscarte: una cara que solo mira al panel es un adorno; una que de vez en cuando
levanta la vista es alguien esperando.

**Nada de esto puede trabarse**, y es por construcción: las reacciones son
*curvas que se apagan solas*, no estados. La despedida es lo único que no la
dispara un cambio de opción sino un botón mantenido, así que es lo único que
podría quedarse puesto: por eso, además de que el menú la refresca en cada
cuadro, **se apaga sola** si el menú deja de hablarle (al abrir un panel, por
ejemplo). No hay banderas que se puedan quedar
encendidas ni nada que esperar a que termine. Si cambias de opción a media
reacción, la nueva empieza de cero y el cuerpo llega a ella suavizado, así que
tampoco da un tirón. `prueba/ui` comprueba las dos cosas: que las cuatro
reacciones son distintas entre sí y que a los 6 s todas han vuelto al reposo.

**Por qué 3D vivo y no una hoja pre-renderizada** como el resto del arte: lo que
hace que algo se sienta tridimensional no es estar sombreado, es **responder**.
Al cambiar de opción la cámara se desplaza **1,64 unidades**, y el paralaje
entre las placas cercanas y las lejanas solo se puede leer como distancia. Un
giro pre-renderizado es una animación; una cámara que se mueve es volumen.

El toro hace el trabajo pesado del decorado a propósito: su silueta cambia por
completo al girar, de circunferencia a elipse a línea. Una esfera girando no dice
nada, porque un círculo es un círculo desde todos lados. Al personaje le pasa lo
contrario y por eso el vaivén de la cabeza no para nunca: al girar, un ojo tapa
un poco al otro y la sonrisa se acorta, y eso sí cuenta que hay bulto.

Cuesta **92 dibujos por cuadro** (81 antes de meter al personaje). Sin sombras, sin resplandor de entorno y sin
reflejos: en GL Compatibility o no existen o se pagan caros, y el resplandor
sale más barato con material emisivo.

Dos trampas que costaron una vuelta:

1. **`_draw()` empezaba pintando un rectángulo opaco a pantalla completa**, así
   que tapaba la escena entera y el menú se veía exactamente igual que antes de
   montarla. De paso se fue el degradado falso que simulaba profundidad: ahora
   la profundidad es real.
2. **La escena 3D va en un `CanvasLayer` con `layer = -1`, no colgada del
   Control.** Un `CanvasItem` se dibuja ANTES que sus hijos, así que ahí dentro
   taparía todo lo que pinta `_draw()`.

### La historia: intro y final

La historia se cuenta con **láminas que hierven** (el método de *The Binding of
Isaac*): dos dibujos casi iguales por viñeta, alternados cada 0,1 s, sobre una hoja
apoyada en un escritorio. Nada es vídeo ni animación por tween. `scripts/cine.gd`.

**La intro** (17 láminas, ~66 s) cuenta que TSL-04 era la cuarta celda de prueba
de un centro de datos, NIMBUS-9, con las otras tres ya apagadas; que un rayo la
despertó, que el suelo se encendía detrás de ella, que la máquina la llamó ERROR 04
y mandó borrarla, y que echó a correr con muy poca carga. Termina en la viñeta 8,
en el conducto, con un reloj de arena.

**El final** va **después del nivel 3**, y de ahí el juego sigue en el 4.

Salió del propio storyboard: `laminas.py` dice «las 9 viñetas… replicando el
storyboard original», y **la viñeta 9, «el escape», nunca se usó**. En ella TSL-04
revienta la pared del edificio, cruza la ciudad dejando su estela y llega a una
granja. El final la recupera y la rodea de seis láminas nuevas (19–24) que
**riman con la intro**, porque una rima se reconoce sin explicarla:

| En la intro | En el final |
|---|---|
| 8 · el conducto, con el reloj de arena | 19 · el conducto acaba en una rejilla con luz de día |
| 13 · «Arriba, algo lo miraba todo» | 13 otra vez · «…Pero a ella ya no la vio» |
| — | 9 · el escape: la viñeta original del storyboard |
| 14 · «Dio un paso. El suelo se encendió detrás de ella» | 21 · «Dio un paso. El suelo no se encendió» |
| 18 · «le quedaba muy poca carga» | 22 · «El sol empezó a llenarle la carga», con el reloj de arena tumbado |
| 8 · «echó a correr. Y no ha parado desde entonces» | 23 · «Y por primera vez desde aquella noche, TSL-04 se paró» |
| 11–12 · cuatro celdas, tres apagadas | 24 · «A su lado se encendieron otras tres luces» |

La frase de la 23 no es decoración: en PULSO **pararse mata**. Que pueda pararse es
el final feliz dicho con la regla del juego.

El amarillo no aparece en la intro; en el final es la luz de fuera, el día.

#### Que no se pise nada

Era la condición: ni niveles solapados, ni audios, y respetando la salida de cada
uno. Lo comprueba `prueba/final` **con los cambios de escena de verdad**:

- **La salida del nivel 3 dura lo de siempre**: 1,55 s medidos (sonido del portal
  y celebración, fundido a negro a los 0,9 s, cambio de escena a los ~1,5).
- **El portal suena entero** (0,90 s) antes de que empiece a irse la música, a los
  0,90 s.
- **`circuito` se apaga con el fundido a negro**, en su mismo medio segundo, y al
  cambiar de escena ya no suena. Entre niveles normales la música sigue sin
  cortarse; solo hacia el final se apaga.
- **Nunca hay dos escenas vivas**: cuando el final es la escena actual, el nivel 3
  ya no existe (ni un nodo en el grupo `jugador`), y cuando llega el nivel 4, la
  cinemática ya no existe.
- **El tema del final, «libre», entra ya en negro** y desde silencio, y se va con la
  imagen: el rótulo FIN queda en silencio y el nivel 4 arranca su música limpia.
- **Saltarlo** corta «libre» en seco en vez de con fundido. El nivel 4 pide
  `circuito` en su `_ready`, y cambiar de tema en el único reproductor a mitad de
  un fundido se oye como un tropiezo.
- Dos temas **no pueden sonar a la vez por construcción**: hay un solo reproductor
  de música. Lo que había que evitar eran los cortes.

El final dura 36,3 s con fundido y rótulo, y «libre» dura 38,4: **no llega a dar la
vuelta**.

**Por qué después sigue el nivel 4 y no el menú**: JUGAR empieza siempre por la
intro y el nivel 1, así que si el final llevara al menú nadie volvería a ver la
chimenea ni los niveles 5 y 6. Cambiarlo es una línea: `SIGUIENTE_FINAL` en
`scripts/cine.gd`. Al menú se vuelve después del último, el 6 (`_siguiente` en
`nivel.gd`).

Intro y final son **el mismo script** (`final = true` en `CineFinal.tscn`): si
fueran dos, se desincronizarían al primer retoque.

#### La música del final

«libre», también sintetizada en `build_musica.py`. **Do mayor, la relativa de
la menor**: son exactamente las mismas notas que `circuito`, pero resuelven hacia
arriba. A 100 BPM y con el latido **una vez por compás** en vez de en cada negra:
en el juego el pulso constante dice «no pares»; aquí ya puede parar. Sin tic de
reloj ni arpegio de datos. Colchón de triángulos y una caja de música que no pasa
de 880 Hz, por debajo de los 1046 del aviso de peligro.

`circuito` **sale idéntico byte a byte** después de añadir «libre» (misma huella
MD5), porque `ruido()` tiene estado global: `circuito` se genera primero y «libre»
no usa ruido.

### El pozo y la adherencia

La adherencia a la pared estaba programada, animada y con coste de carga, pero
al abrir los niveles se quedó sin una sola pared y no se disparaba nunca. El
**nivel 4, La chimenea**, la rescata: un pozo de 5 celdas de ancho y 22 de alto
que solo se sube saltando de pared a pared.

Medido en el motor: se pega, desliza frenado a **46 px/s** (el valor
configurado) y cada salto de pared **gana 113 px** de altura, contra los 100 que
predice la física. Cuatro saltos suben el pozo entero.

Dos cosas hubo que enseñarle al proyecto:

1. **El verificador confundía pared con techo bajo.** Marcaba la chimenea como
   tramo apretado. Contra una pared no te golpeas la cabeza, te topas de lado —
   y es justo donde el juego quiere que te pegues. Ahora un bloque más alto que
   ancho no cuenta como techo.
2. **Las paredes tienen su propia textura.** Usar la del suelo repetía la tira
   cian del canto superior en cada celda, y esa tira significa «aquí se pisa»:
   le estaba mintiendo al jugador. La pieza `pared` lleva las pistas en
   vertical y la luz en los **cantos laterales**, que es de donde sí se agarra.

### Los niveles grandes: Lasermania y Runthedrun

Después del nivel 4 vienen dos niveles hechos a mano y mucho más largos que los
cuatro primeros, y al pasar el 6 se vuelve al menú. Hasta el 20 de octubre de 2026
ahí había niveles generados sin fin; se quitaron a petición del autor y los
sustituyen estos dos.

| | Lasermania (nivel 5) | Runthedrun (nivel 6) |
|---|---|---|
| Escena | `n5_lasermania.tscn` | `n6_runthedrun.tscn` |
| Ancho | 545 celdas | 515 celdas |
| Del anclaje al portal | **8.320 px**, unas 5,5 veces el nivel 1 entero | **7.664 px** |
| Par | 110 s | 75 s |
| Balizas | 5, o sea **6 tramos** de carga | 4, o sea **5 tramos** |
| Peligros | 16 láseres | 10 drones de purga y 2 tiras de pinchos |
| Fragmentos | 3 | 3 |

Los dos van **en un solo sentido**: se aparece a la izquierda y el portal está al
fondo a la derecha, con la terminal antes y la puerta justo delante del portal.
No hay vuelta.

#### Las balizas

`scripts/baliza.gd` y `escenas/obstaculos/Baliza.tscn`, que reusa el dibujo del
anclaje. Existen por una cuenta: una carga completa dura 62 s y morir era empezar
el nivel otra vez. Un nivel de 500 celdas no cabe en una carga, ni se puede
repetir entero cada vez que te coge un láser.

La primera vez que se pisa, una baliza **recarga a tope** (100 %) y **pasa a ser
el punto de reaparición**, y el HUD dice «punto de control» durante 1,6 s. Además
es **toma de tierra**, como la terminal: la estela no prende encima, así que es el
único sitio donde se puede parar, por ejemplo a esperar a que se apague un láser.

Morir con una baliza pisada **reaparece en ella**, con la carga a tope y los
peligros en su pose de partida, pero **sin deshacer** los fragmentos cogidos, la
terminal ni la puerta, y **sin parar el cronómetro**: las muertes cuestan tiempo.
El reinicio completo (la R o «Reiniciar nivel» en la pausa) borra las balizas y
vuelve al anclaje. Los niveles sin balizas, del 1 al 4, se comportan exactamente
igual que antes: morir es empezar de nuevo.

#### Lasermania

Seis tramos, con una baliza al empezar cada uno salvo el primero:

1. **La calle**: un pasillo llano de 100 celdas con cuatro cortinas de láser que
   lo cruzan entero.
2. **La escalera**: cuatro peldaños que suben, con cortinas que cruzan dos de los
   saltos.
3. **La segunda calle**, más corta, con cuatro cortinas de tiempos distintos, para
   que no se pueda aprender un solo ritmo.
4. **Otra escalera**, con cortinas en dos saltos. Llevaba dos torretas zapadoras y
   se quitaron (ver «La revisión de los niveles grandes»).
5. **El descenso**: peldaños que bajan 9 filas con huecos de 10, y cortinas en los
   dos últimos saltos.
6. **El final**: un pasillo con dos cortinas, la terminal en una repisa 6 filas
   por encima (hay que subir y volver a bajar), la puerta y el portal.

Cada uno de los 16 láseres lleva sus propios tiempos: reposo, disparo y desfase
cambian de uno a otro, y la carga (el aviso) es siempre de 0,5 s. De los tres
fragmentos, dos flotan entre las cortinas de las calles, a 6 filas del suelo, y se
cogen saltando entre haz y haz; el tercero está sobre el primer peldaño del
descenso.

**Una trampa de las escaleras:** el emisor de un láser cuelga de un montante, que
es un bloque sólido, y tiene que quedar por encima de donde llega la cabeza en un
salto: 8,9 filas sobre la superficie de la que se salta (9,6 con TSL-02). La
primera versión los ponía más bajos y la cabeza chocaba con ellos; está corregido.

#### Runthedrun

Un nivel para **correr**: una ruta larga de plataformas en un solo sentido, con
huecos de 5 a 9 celdas y pequeñas subidas y bajadas. Los drones de purga cuelgan
11 filas por encima de la ruta, más arriba de donde llega un salto: te ven al pasar
por debajo, bajan y **te persiguen para siempre**, a 118 px/s contra tus 220. Quien
sigue corriendo se los deja atrás; quien duda los junta detrás.

- Uno cuelga sobre la salida y echa a perseguirte en cuanto te mueves: se empieza
  corriendo.
- Otros seis, repartidos por la ruta, nunca a menos de 13 celdas de una baliza (te verían al reaparecer).
- 2 tiras de pinchos, en plataformas largas de 26 celdas, nunca antes de donde aterriza TSL-02 (la que más vuela) + 3.
- 3 fragmentos, a 5 filas sobre otras tantas plataformas: se cogen con un salto,
  sin parar.
- Al final, la terminal en una plataforma larga sin drones delante; luego la
  puerta, el portal y tres drones que se despiertan al pasar: el último tramo, a la
  carrera.

Las plataformas de la ruta se sortearon con `random.Random(6)` en `grandes.py`, y
cada hueco está limitado por las mismas fórmulas de alcance que usa
`disena_niveles.py`. La escena es fija: es la misma siempre, no se genera al jugar.

#### Cómo se hacen

`../tsl04/grandes.py` monta los dos con piezas (calles, escaleras, balizas) en vez
de listar a mano 150 bloques, y `disena_niveles.py` los lee igual que a los otros
cuatro: mismos bloques en celdas de 16 px y mismas comprobaciones de alcance.
`python3 disena_niveles.py --solo n5_lasermania` escribe solo esa escena.

De paso salió que `disena_niveles.py` estaba desfasado: todavía escribía los
nodos del HUD viejo. Ahora escribe el `CanvasLayer` del HUD vacío y
`follow_viewport = false`, y solo añade el recurso de la baliza si el nivel tiene
balizas, así que **los cuatro niveles originales salen idénticos byte a byte**.

#### Lo que prueban los bots, y lo que no

`prueba/grandes.tscn` (`prueba_grandes.gd` y `bot_ruta.gd`) comprueba:

- **La estructura**: anclaje, puerta, 3 fragmentos, tantas balizas como tramos
  menos uno, más de 6.000 px de ida sin vuelta, balizas sobre suelo firme, y
  ningún láser, pincho ni torreta a menos de 64 px, ni la patrulla de un dron a
  menos de 200 px, de una baliza o de la terminal.
- **Las balizas**: recargan, fijan el punto de control, avisan en el HUD, no
  deshacen lo hecho y el reinicio completo sí. Y que el nivel 1 sigue
  reiniciándose entero al morir.
- **Que se pueden recorrer**, con bots de ruta:

| Bot | Nivel | Llega al portal en | Muertes |
|---|---|---|---|
| Geometría (sin peligros) | Lasermania | 38 s de juego | 0 |
| Geometría (sin peligros) | Runthedrun | 35 s | 0 |
| Paciente: espera a que se apague cada láser | Lasermania | 45 s | 0 |
| Corredor, con todos los drones | Runthedrun | 39 s | 1 (lo alcanza un dron una vez; pasa al reaparecer) |
| Geometría, con **TSL-02** | Lasermania | 33 s | 0 |
| Corredor con drones, con **TSL-02** | Runthedrun | 31 s | 0 |
| Paciente, con **TSL-02** | Lasermania | 37 s | 0 |

Además, cada recorrido comprueba que **se pisan todas las balizas**.

Los bots van a 4× con **240 ticks de física por segundo**, para que cada tick siga
siendo un paso corto: con `time_scale` solo, cada tick pasaba a ser de 4/60 s y los
saltos salían distintos.

> **Los bots demuestran que cada nivel se PUEDE pasar, no que sea justo ni
> divertido para una persona. Nadie los ha jugado a mano todavía.**

Dos lecciones de diseño que sacaron los bots, las dos en Runthedrun:

1. **Los pinchos no pueden ir donde aterriza el salto anterior** (6–8 celdas
   pasado el hueco) **ni en medio de una plataforma corta**, porque el salto que
   los esquiva acaba pasado el borde. Por eso solo hay en las plataformas de 26
   celdas, a 13 del principio.
2. **Los drones a 6 filas del suelo chocaban con cada salto** que se diera debajo
   de ellos. Por eso cuelgan a 11.

### La revisión de los niveles grandes

Una revisión adversarial (cuatro revisores, uno por ángulo) encontró 8 fallos. Se
comprobaron todos contra el código y se arreglaron, cada uno con su prueba:

- **La tecla de reiniciar durante la ceremonia de salida** reiniciaba el nivel, pero
  la ceremonia seguía y cargaba el siguiente igual, y la pausa podía volver a
  abrirse debajo del negro. Este fallo ya existía antes. Ahora la tecla no hace nada
  en la ceremonia, como la pausa, y la ceremonia comprueba tras cada espera que
  sigue viva.
- **Reiniciar en la pausa de muerte (0,85 s)** dejaba una reaparición pendiente que
  devolvía al anclaje medio segundo después. También venía de antes.
- **Con TSL-02**, que corre a 250 px/s y salta 125 px, Runthedrun tenía una
  plataforma de 8 celdas donde no se podía aterrizar, unos pinchos justo donde se
  aterriza, y una baliza que se podía saltar sin tocarla. A las balizas de
  Lasermania les pasaba lo mismo. Ahora `grandes.py` mide el aterrizaje con el
  personaje que más vuela, saltando tarde con coyote (`aterrizaje()`). De ahí salen
  el ancho mínimo de cada plataforma y dónde van balizas y pinchos. `prueba/grandes`
  repite los recorridos con TSL-02.
- **Una torreta vigilaba el sitio donde se espera a una cortina**: esperar te mataba
  la torreta y no esperar, el láser. La otra dispara medio segundo después de que
  entras en su alcance, así que cruzar su peldaño pedía cebarla, cosa que nada en el
  nivel enseña. Se quitaron las dos, y la prueba comprueba que ninguna torreta
  alcanza la espera de una cortina.
- **Cuatro fallos de las pruebas**:
  - El doble toque en JUGAR caía en el hueco entre las tarjetas 3 y 4, y la prueba
	pasaba aunque faltara la guarda.
  - La comprobación de la fase de los láseres solo pasaba porque el primero tiene
	desfase 0.
  - Las torretas se medían con 64 px en vez de con su alcance.
  - Tras la primera muerte, la congelación devolvía `time_scale` a 1 y el bot dejaba
	de ir a 4×, con ticks de 1/240 s.

### El ciclo de muerte

Pausa de 0,85 s en tiempo real, reinicio completo de los peligros, y 1,1 s de gracia
parpadeando al reaparecer. Antes los enemigos te remataban en bucle. Con una baliza
pisada (niveles 5 y 6) no se reinicia el nivel: se reaparece en ella (ver «Las
balizas»).

### Los niveles

Tres archipiélagos abiertos sobre el vacío: sin marco, sin techos, y caerse mata.

| | |
|---|---|
| Hueco entre plataformas | 112 px = **4,0 veces el personaje** |
| Separación vertical ida/vuelta | 128 px = 4,6 × |
| Aire libre sobre las plataformas | 96 px = 3,4 × |

La regla que aguanta, medida con un bot que corre y salta al borde: **subida de 2
celdas admite hueco de 3; subida de 3 exige hueco de 2**. El verificador exige 56 px
de holgura en cada salto de subida o el nivel no se genera limpio.

### El arte

Todo se genera con scripts de Python sobre **Blender 5.2.1**, en `../tsl04/`. Nada se
modeló a mano, así que cualquier cambio es reproducible.

- **`rayos.py`** — generador de rayos según el modelo de ruptura dieléctrica. Pasos
  dentro de ±30° el 54 % de las veces (la literatura dice «poco más del 50 %»), ramas
  a 20–45°, canal que se afila, y una tensión que tira hacia el electrodo sin la cual
  el paseo aleatorio se enrosca. Se ejecuta sin Blender y sabe medirse.
#### Por qué el personaje se veía plano

No estaba plano: estaba **quemado**, y el histograma de luminancia lo escondía.
Midiendo por CANAL salta la causa.

| | Antes | Ahora |
|---|---|---|
| Canal **azul** clavado en 255 | 54,6% del cuerpo | **17,1%** |
| Canal **verde** clavado | 49,0% | **8,2%** |
| Píxeles quemados a blanco (>245) | 17,5% | **8,1%** |
| Mediana / p25 / p75 | 227 / 158 / 232 | **164 / 131 / 200** |
| Píxeles en sombra (<90) | 10,5% | 11,7% |

En más de la mitad del cuerpo solo quedaba vivo el rojo, que en la paleta cian
vale 0,13 de 1,00: toda la forma se contaba con un tercio de la información.
Tres correcciones, **todas de exposición**:

1. **La clave estaba casi frontal** (Y=−2,8, con la cámara en Y=−5,6). La luz
   frontal aplana por definición: el terminador queda detrás de la silueta y no
   llega a cruzar la cara visible. Movida al lado y de 340 W a 190.
2. **Los bordes eran el culpable principal**: sumaban 820 W contra una clave de
   340, o sea 2,4 veces. Está al revés. El borde describe la **silueta**, que ya
   se lee sola contra el fondo oscuro; la clave describe la **forma**, que era
   lo que faltaba. De 560 a 120.
3. **La emisión del cuerpo** (0,32) era un suelo de brillo que se suma igual en
   todos los píxeles sin mirar la normal. A 0,07 conserva el brillo propio del
   personaje sin ser un velo.

Y el ambiente deja de estar a cero (0,55, del tono del fondo del juego): sin él
el terminador es un corte y la sombra se hunde a negro sin información.

**El tonemapping NO se tocó, y es decisión activa.** Se probaron AgX, Filmic y
Khronos PBR Neutral renderizando de verdad: AgX deja la saturación en 0,200
frente a 0,526 y el cian se vuelve gris lechoso; Filmic levanta los negros de 35
a 51, y sobre el fondo del juego eso deja un halo gris alrededor del alfa. El
comentario original tenía razón — un tonemapper cambia un corte duro por un
hombro blando en el mismo sitio, pero no devuelve el volumen.

**Lo que sigue pendiente: la silueta.** `tsl04_victoria.png` da un giro completo
de 360°, y el cuadro girado 140° sale **más redondo** que el de partida
(circularidad 1,25 contra 1,19; IoU entre cuadros 0,958–0,996). El cuerpo da una
vuelta entera y la silueta no se entera, porque es una esfera. Hay un diseño
medido para arreglarlo (anillo ecuatorial inclinado, espiga y dos aletas
traseras, con sus medidas en píxeles) que no se ha aplicado: cambia la identidad
del personaje y esa decisión es de Jose, no mía.

#### La sombra de contacto

El personaje ya no estaba quemado, pero seguía **flotando**: `Jugador.tscn` solo
llevaba colisión, sprite y cámara, y nada lo relacionaba con el suelo. Ahora
lleva una sombra (`scripts/sombra.gd`) que hace tres trabajos a la vez: dice
dónde está el suelo, dice a qué altura va el personaje, y **en el aire anticipa
dónde vas a caer**, que en un juego donde pararse mata es información útil.

- **Está EN el suelo**, no a un desfase fijo: un rayo hacia abajo desde los pies
  y la sombra en el punto de impacto. Al saltar se queda abajo.
- **Encoge y se aclara con la altura**, monótonamente, y desaparece a 150 px. El
  salto es de 115: en la cima sigue viva (alfa 0,145), que es cuando más sirve.
  La primera versión caía con el cuadrado y quedaba a alfa 0,03 en la cima,
  invisible justo cuando hacía falta.
- **No se dibuja sobre el vacío** ni con el jugador muerto.
- **Va detrás del sprite y delante de las plataformas** sin un solo `z_index`: es
  hijo de `Jugador` y está antes que `Sprite` en el árbol. No usa `top_level`,
  que la sacaría del orden del padre.
- **Se lee sobre la placa casi negra** porque no cae sobre la placa: cae sobre el
  canto de la plataforma, que lleva la tira cian de «aquí se pisa». Tapar esa
  tira es lo que se ve.

Una figura por cuadro y ninguna textura importada. Prueba: `prueba/sombra`.

- **`build_tsl04.py`** — TSL-04, sus 12 animaciones y el modelo `.glb` del menú. Aplastado y estirado con
  **volumen constante** (antes se inflaba un 18 %), arrastre de la cabeza (al acelerar
  se queda atrás, al frenar se pasa de largo) y ritmo por cuadro normalizado para que
  cada animación dure exactamente lo mismo.
- **`build_elementos.py`** — los once objetos. El bloque de suelo es un trozo de placa
  de circuito: sustrato, pistas de cobre en ángulo recto, pads con vía y aletas de
  disipador.
- **`build_estela.py`** — la estela, con núcleo blanco y halo de color.
- **`build_fondo.py`** — el fondo animado: 16 cuadros a 8 fps con paquetes de datos
  recorriendo los buses y LEDs parpadeando. El bucle cierra exacto porque los paquetes
  van espaciados S y avanzan S/16 por cuadro.
- **`disena_niveles.py`** — los niveles y sus tres verificadores (alcance, holguras,
  techos bajos). Los niveles 5 y 6 los monta **`grandes.py`**, con piezas.

Dos trampas del pipeline, anotadas para no repetirlas:

1. **El bloom de EEVEE no se guarda en PNG con fondo transparente.** El resplandor
   tiene que ser geometría: tubos concéntricos separados en profundidad, porque si no
   el más ancho tapa al núcleo.
2. **Godot sirve la textura importada en caché.** Al reemplazar un PNG hay que borrar
   `.godot/imported/` y reimportar, o el juego sigue mostrando el arte viejo.

### Los efectos

Autoload `Efectos`. La muerte hace lo que pide el GDD: congelación de 0,08 s, destello
blanco, sacudida de 3 px, 24 chispas y aberración cromática que se disuelve en 0,2 s.
Los obstáculos avisan al encenderse, pero **solo si el jugador está cerca**.

---

## Las pruebas

45 escenas en `prueba/`. Se lanzan sin ventana:

```bash
/Users/joserico/Documents/Archivo_Organizado/05_Software/Aplicaciones/Godot.app/Contents/MacOS/Godot --headless --path . prueba/muerte.tscn
```

| Prueba | Qué comprueba | Estado |
|---|---|---|
| `flujo` | encadenado de los 3 primeros niveles | OK |
| `niv` | geometría de los tres niveles | OK |
| `muerte` | pausa, reinicio de peligros, gracia, vacío | 0 fallos (8/8) |
| `drones` | inercia, ladeo, cabeceo, giro amortiguado | 0 fallos (6/6) |
| `obst` | máquinas de estado de los peligros | 1 fallo conocido¹ |
| `bot` | recorrido de ida y vuelta de los tres niveles | pasa entero |
| `prueba` | cobertura de animaciones | 10/12² |
| `rend` | presupuesto de dibujo | 13 de 60 |
| `guardado` | progreso, mejor marca y archivo corrupto | 0 fallos (13/13) |
| `tactil` | multitáctil, zonas, pérdida de foco | 0 fallos (11/11) |
| `pausa` | congela, vuelve al sitio, botón atrás, la flecha arriba no elige, un toque cuenta una vez | 0 fallos |
| `audio` | carga, solapado, silencio, pausado | 0 fallos (5/5) |
| `aspecto` | los mandos se recolocan en 19,5:9 y 20:9 | OK |
| `ui` | menú, escena 3D, TSL-04 (piezas, mirada, reacciones), que OPCIONES abre CONTROLES y cinemática | 0 fallos |
| `teclas` | reasignación sin pantalla: las tres promesas tras cada operación, disco, guardados rotos, nombres | 0 fallos (52/52) |
| `controles` | la pantalla con teclas de verdad: que cabe a 640 y 780, escucha, cancelar, 5 s, Supr, restaurar, rueda y toque | 0 fallos (46/46) |
| `personajes` | el alcance, la pega de cada uno, la pared y la carga a ritmo de par por tramo, desbloqueos, personaje forzado, jugador y estela de los cuatro, el selector | 0 fallos |
| `selector` | NIVELES: las seis tarjetas, tabla igual a las escenas, cabe en 3 tamaños, abierto/cerrado, teclado, dedo, Volver, personaje, doble toque, el final y su música, la primera vez | 0 fallos (66/66) |
| `menu_tactil` | el menú con dedo y ratón en 16:9, 19,5:9 y 4:3: filas de 46 px, arrepentirse, SALIR mantenido, un toque = una vez, varios dedos, toque cancelado, foco, botón atrás, la intro | 0 fallos (58/58) |
| `pared` | adherencia, deslizado y altura del salto de pared | 0 fallos (6/6) |
| `grandes` | niveles 5 y 6: estructura, balizas, que el nivel 1 sigue reiniciándose entero, y bots de ruta hasta el portal | 0 fallos (28/28) |
| `fondo` | que el fondo cubra la pantalla de punta a punta del nivel, también en el 5 y el 6 | 0 fallos |
| `aparicion` | que el jugador nazca donde toca en los 6 niveles | 0 fallos (24/24) |
| `musica` | bus propio, bucle, atenuación en pausa | 0 fallos |
| `estela` | el reloj de la estela, que no puede ser el de pared | 0 fallos |
| `fundido` | el paso de un nivel al siguiente | 0 fallos |
| `hud` | el cerco, los rombos y el cronómetro | 0 fallos |
| `sombra` | sombra en el suelo, monótona con la altura, oculta sobre el vacío | 0 fallos (11/11) |
| `ajustes` | asistencia idéntica apagada, rejilla viva, vibración, la fila en la pausa | 0 fallos (19/19) |
| `final` | nivel 3 → final → nivel 4 con cambios de escena reales: tiempos, audio, escenas | 0 fallos (30/30) |

Tres fallos que se encontraron sin buscarlos, todos silenciosos:

1. **127 rectángulos de lado ≤ 0** en los antiguos niveles generados, a partir
   del 16: el suelo acababa pegado al techo del mapa y la pared salía con altura
   negativa (`RectangleShape2D size cannot be negative`). No lo cogía ninguna
   prueba porque todas usaban niveles bajos. Aquellos niveles ya no existen; la
   lección, probar también los casos de los extremos, sigue valiendo.
2. **`prueba/ui` llevaba un día entero colgada**: miraba `cine.toma` y
   `cine.TOMAS`, que ya no existen — `cine.gd` cuenta por `beat` y `BEATS`.
   Erraba en cada fotograma y nunca terminaba. Lleva guardia de tiempo: una
   prueba que no acaba, falla.
3. **El fondo se iba a partir de x=2.050 px.** Un `Parallax2D` con
   `follow_viewport = true` dentro de un `CanvasLayer` con
   `follow_viewport_enabled = false`: el desplazamiento se aplicaba **dos
   veces**, y el fondo derivaba a +0,75× en vez de −0,25× — al revés y tres
   veces más rápido — hasta salirse del mosaico. No se veía en los niveles a
   mano porque miden 1.056–1.440 px.

Y una trampa de medición que conviene no repetir: **el color de borrado del
proyecto es casi negro, igual que el sustrato de la placa del fondo**, así que
contar píxeles oscuros no distingue «falta el fondo» de «aquí el fondo es
oscuro». La primera medición dio 0,0% de fallo y era falsa. `prueba/fondo` pinta
el borrado de magenta antes de medir.

La prueba de guardado escribe en el archivo de progreso **de verdad**, así que
ahora se lo guarda antes y lo devuelve como estaba. Antes, pasar las pruebas te
borraba la partida y dejaba el archivo a medias, y todas las escenas siguientes
arrancaban con un «progreso ilegible».

**`prueba/fundido` tampoco lo devolvía**, y se notaba: sale del nivel 1 a los
0,8 s para medir el fundido, y eso llama a `Guardado.completar_nivel()`. Cada vez
que corría un poco más deprisa, **«mejoraba» el récord del nivel 1** de quien
juega. Ahora copia el archivo y lo devuelve. El 0,80 s que había guardado como mejor tiempo del nivel 1 lo había escrito esta
prueba, no una partida (se borró con los demás récords falsos).

¹ El «fallo» del dron de purga es un artefacto: la prueba lo pega al jugador y salta
directo a `alerta` sin pasar por `patrulla`.
² `adherencia` **ya se dispara** desde el nivel 4. `carga_baja` sigue siendo rara
porque pararse mata, pero es alcanzable: en la terminal puedes estar quieto,
porque es toma de tierra.

**Los bots ya saben trepar.** Antes se plantaban en el primer pozo y esperaban a
que la estela los matara. Enseñarles costó cuatro correcciones, todas del bot y
ninguna del juego, y todas por lo mismo: mandar por código no es lo mismo que
tocar el mando.

1. **El salto es de altura variable.** Soltar el botón mientras subes recorta la
   velocidad al 45%, o sea la altura al 20%. Soltándolo al fotograma siguiente,
   una trepada entera se quedaba en 31 px de los 115. Ahora se retiene 32
   fotogramas, que es lo que dura la subida (474,8 / 980 = 0,48 s).
2. **Lo que el bot lee va un tick atrasado**, porque su nodo corre antes que el
   jugador. Por eso ninguna decisión puede depender de `velocity`.
3. **Estando pegado hay que apretar CONTRA la pared.** La adherencia exige que
   el eje apunte a la pared; soltándola en el mismo fotograma que se pulsa
   salto, `pegado` se cae y el salto de pared no llega a dispararse: el bot solo
   se despegaba y volvía al fondo.
4. **Y al despegar, rumbo a la salida**, no a la pared de enfrente. El salto de
   pared ya empuja hacia atrás; volviendo a apretar hacia adelante se cancela
   ese empujón y se vuelve a la misma pared más arriba. Apuntando enfrente, el
   bot salía del pozo por el lado malo y caía dentro otra vez.

Con las cuatro desaparecieron las dos muertes del nivel 2 y el bot sube más alto
en el 1 y el 3.

Lo que sigue sin hacer el bot es **encontrar la boca del pozo del nivel 4**: llega
arriba, se asoma, y como su regla de «¿hay dónde caer?» solo miraba 104 px hacia
abajo, se daba la vuelta. Se le amplió la vista a 480 px —en PULSO caer no hace
daño, lo que mata es el vacío— y aun así se le escapa. Que ese pozo se sube está
medido aparte en `prueba/pared.tscn`: cuatro saltos de pared, 113 px cada uno.

---

## Exportar a escritorio (las entregas del curso)

`export_presets.cfg` tiene, además del de Android, un preset **Windows** (un solo
`PULSO.exe` con el juego dentro, x86_64) y uno **macOS** (`PULSO.app` universal,
x86_64 + arm64, con firma *ad hoc*). Los dos dejan fuera `prueba/`.

```bash
Godot --headless --path . --export-release "Windows" ../exportar/windows/PULSO.exe
Godot --headless --path . --export-release "macOS" ../exportar/mac/PULSO.zip
```

- Hacen falta las plantillas de exportación de 4.7.2. Se instalaron el 1 de
  noviembre de 2026, desde el GitHub oficial de Godot, con la suma SHA-512 comprobada.
- El de Mac exigía **Importar ETC2 ASTC** (Renderizado > Texturas > Compresión
  VRAM): sin eso no se exporta para los Mac con chip Apple. Está activado en
  `project.godot`, y Android también lo necesita.
- La entrega de la Actividad 3 está en `/Users/joserico/pulso/entrega/`: el zip
  lleva los dos ejecutables y un `LEEME.txt` con cómo abrirlos y los controles.

## Qué falta para subir a Play Store

Ahora mismo esto es un **prototipo de escritorio muy pulido**, no un producto. Lo que
separa una cosa de la otra, por orden de qué bloquea qué.

### Bloqueantes técnicos

| | Estado |
|---|---|
| **Controles táctiles** | ✅ Hechos y probados (multitáctil incluido). |
| **Guardado** | ✅ Hecho, aguanta archivo corrupto. |
| **Menú de pausa** | ✅ Hecho, con botón atrás de Android. |
| **Sonido** | ✅ Nueve efectos y un tema de música de 64 s con bus propio. |
| **Relación de aspecto** | ✅ `expand`: en 19,5:9 se ve más ancho, sin franjas. |
| **Preset de exportación** | 🟡 **Escrito** (`export_presets.cfg`, ver «Exportar a Android»). Godot lo lee y solo protesta por lo que falta en el equipo: plantillas de Android, Java y el SDK. |

El renderizador ya es **GL Compatibility**, que es el correcto para móvil.

### Lo que Google exige

- **AAB** (Android App Bundle), no APK, para publicaciones nuevas.
- **64 bits** y el nivel de API que Google exija ese año — sube cada año, así que hay
  que mirarlo justo antes de publicar.
- **Keystore de firma** propio, guardado a buen recaudo: si se pierde, no se puede
  volver a actualizar la app.
- **Cuenta de desarrollador**, pago único de 25 USD.
- Si la cuenta es **personal y nueva**, Google pide **12 probadores durante 14 días
  seguidos** en pruebas cerradas antes de dejarte pasar a producción. Eso se planifica
  con semanas de antelación, no el día antes.
- **Cuestionario de clasificación por edades** (IARC) y **formulario de seguridad de
  datos**. Este último es obligatorio aunque no recojas nada.
- **Política de privacidad** publicada en una URL accesible.
- Ficha de tienda: icono 512×512, gráfico destacado 1024×500, y capturas.

#### Lo que ya está preparado

**La política de privacidad y los formularios**, en borrador:
[`PRIVACIDAD.md`](PRIVACIDAD.md). Política en español y en inglés, respuestas
sugeridas para «Seguridad de los datos» y para IARC, y cómo publicarla gratis en
GitHub Pages. Nada se afirma sin evidencia: sale de una **auditoría del código**
cuyos comandos están en el propio documento. Resultado: ni una API de red, ni
identificadores de dispositivo, ni anuncios, ni compras, ni analítica, y lo único
que escribe a disco es `user://progreso.json`, que no sale del teléfono.

Falta que Jose rellene tres huecos (correo, fechas), lo revise y lo publique. Y
hay una decisión que es suya: si en Play Console marca un público **menor de 13
años**, la app entra en la Política de Familias de Google, que es más estricta.

**Los recursos gráficos**, en `/Users/joserico/pulso/ficha_tienda/` (fuera del
proyecto a propósito: un PNG dentro de `pulso-godot/` lo importa Godot). Todos
comprobados contra la especificación, con números:

| Archivo | Tamaño | Formato | Peso |
|---|---|---|---|
| `icono_512.png` | 512×512 | RGBA | 168 KB |
| `destacado_1024x500.png` | 1024×500 | RGB, sin alfa | 106 KB |
| `captura_1_nivel.png` … `captura_6_personajes.png` | 1920×1080 | RGB | 210–646 KB |

- **El icono se juzga pequeño**: está reducido a 48 y 96 px al lado para
  comprobarlo, y a 48 px TSL-04 sigue siendo una cara, no una bola. Fondo lleno
  hasta el borde, porque Google aplica su propia máscara.
- **Las capturas son del juego de verdad**, que es lo que exige Google: se
  cargan los niveles, se juega con la entrada real y se fotografía el viewport.
  Las saca `prueba/capficha.tscn` (con ventana; `SOLO=6` saca una sola). La
  primera versión de la del nivel 1 salió con el personaje **cayéndose al vacío**,
  por correr a ciegas hacia la derecha en un archipiélago; ahora va hacia la
  puerta y el portal.
- **Son seis** (actualizadas el 20 de octubre de 2026): 1 nivel 1, 2 la chimenea,
  **3 Lasermania** (`captura_3_lasermania.png`: TSL-04 por la primera calle, con
  una cortina de láser disparando justo delante; `SOLO=3`), 4 el menú, **5 la
  pantalla NIVELES** y **6 TSL-02 corriendo en el nivel 2** con su estela violeta.
  Google pide de 2 a 8. La antigua `captura_3_generado.png` se borró.
  - La 5 usa un progreso puesto **en memoria** (`PROGRESO` en `cap_ficha.gd`: los
	cuatro niveles pasados, 12 fragmentos y tiempos cerca del par): es un estado al
	que se llega jugando, pero **los tiempos no son récords de nadie**, y nada de
	eso se guarda.
  - La 6 salió la primera vez con TSL-02 **cayéndose al vacío**, igual que la del
	nivel 1: a 250 px/s la primera plataforma se acaba enseguida. Ahora se
	fotografía a los 0,36 s, todavía encima.
  - Las seis enseñan a TSL-04 sin asistencia salvo la 6, que fuerza a TSL-02:
	`Personajes.forzado` y la asistencia se fijan en memoria, para que la ficha no
	dependa del personaje ni de los ajustes de quien la saque. El archivo de
	guardado se copia al empezar y se devuelve al terminar.
- En el **destacado** se ocultan TSL-04 y su anillo de la escena 3D: quedaban
  debajo del logotipo y saldrían **dos TSL-04** en la misma imagen, el del mundo
  3D y el retrato.

Las especificaciones usadas son las conocidas, **no están confirmadas contra la
documentación vigente de Google**: hay que repasarlas al subir.

### Experiencia de usuario en móvil

Esto es lo que decide si alguien lo desinstala en el primer minuto.

- ✅ **Relación de aspecto** resuelta con `expand`: en un móvil de 2340×1080 el
  viewport pasa de 640 a 780 de ancho, sin franjas negras, y los mandos se
  recolocan solos.
- ✅ **El botón de accionar** ya no existe: la terminal se activa sola.
- ✅ **El botón atrás de Android** pausa en vez de cerrar.
- ✅ **El HUD cabe.** Rehecho entero en `scripts/hud.gd`, sin texto que se corte:
  barra, segundos, rombos y cronómetro. Comprobado en las capturas de la ficha, a
  640 px lógicos.
- ✅ **Vibración al morir**, 70 ms, activable desde la pausa. Por debajo de ~30 ms
  muchos motores ni arrancan y por encima de ~120 se nota como zumbido, no como
  golpe. **En Android necesita el permiso `VIBRATE`** en el preset de
  exportación, que hoy no existe.
- **Se juega en silencio.** Mucha gente juega en el metro sin sonido, así que la
  información crítica no puede vivir en el audio. Aquí eso ya se cumple: los peligros
  avisan con luz y movimiento antes de matar.

### Contenido

Seis niveles hechos a mano suman **401 segundos** de par: 216 los cuatro primeros,
110 Lasermania y 75 Runthedrun. Después del 6, el juego vuelve al menú.

✅ La **adherencia a la pared** ya está rescatada con el nivel 4.
✅ Los niveles largos ya caben, gracias a las **balizas**.

Lo que falta: **que una persona juegue los niveles 5 y 6**, porque hasta ahora solo
los han pasado bots, y más niveles hasta llegar a 15–20.

### Accesibilidad — esto ya está bien

Comprobado simulando dicromatismo sobre la paleta (Viénot 1999):

```
par                normal    protanopia  deuteranopia
rojo vs volt       0.796     0.748       0.538        OK
rojo vs ambar      0.526     0.494       0.368        OK
rojo vs cian       1.324     0.996       1.014        OK
```

Aguanta, y la razón es que el **rojo es mucho más oscuro** que el resto: luminancia
0,238 frente a 0,763 del volt. Se distinguen por claridad aunque falle el tono, así
que funcionan hasta en escala de grises. Conviene no tocar esas luminancias.

#### El modo asistencia

El juego pide precisión y no perdona. El **modo asistencia** (en la pausa,
apagado por defecto) alarga el retardo de la estela de **0,35 a 0,70 s**. La
cuenta: 0,35 s está por debajo del tiempo de reacción de una elección (0,4–0,5 s
en adultos), así que el juego normal exige anticiparse, no reaccionar. 0,70 s da
una reacción completa de margen, y **pararse sigue siendo un error**: la celda
sigue matando, solo que después.

Tres cosas que había que hacer bien:

- **Con la asistencia apagada el juego es idéntico.** Es lo más importante y lo
  comprueba `prueba/ajustes` al segundo: la celda mata desde 0,35 s, ni antes ni
  después.
- **La animación de encendido se estira al retardo.** Si no, con 0,70 s acababa a
  los 0,35 y la celda se veía encendida del todo sin matar todavía: le mentía al
  jugador. Así «encendida del todo» sigue significando «ya mata».
- **Se aplica a la rejilla viva**, sin reiniciar el nivel. Reiniciar para cambiar
  un ajuste castigaría precisamente a quien lo busca porque le cuesta.

`RejillaEstela.RETARDO` sigue siendo constante, porque hay pruebas que la leen
como referencia del juego normal; el valor que manda es `retardo`.

**En la pausa, tres interruptores en una sola fila** (cerco fijo, asistencia,
vibración) y no una página nueva. El menú ya ocupaba 302 de 360 px y dos filas más
no cabían; una segunda página sí, pero escondía los ajustes detrás de un toque
más. Encendido es relleno cian, apagado es solo contorno, que es el mismo
vocabulario que las celdas de volumen. Izquierda y derecha **mueven el foco sin
cambiar nada**: si los cambiaran, recorrer la fila con el mando iría encendiendo y
apagando todo lo que tocara.

Una trampa de la prueba, no del juego: `100,35 − 100` en coma flotante da
`0,3499999999999943`, menor que 0,35, y la prueba fallaba sin que nada hubiera
cambiado. Las celdas se marcan en t = 0 para que la resta sea exacta.

---

## Orden que yo seguiría

1. ✅ **Táctil + pausa + guardado.**
2. ✅ **Sonido**: efectos y música.
3. 🟡 **Exportar y probarlo en un teléfono de verdad.** El preset y los iconos están
   hechos; faltan Java 17, el SDK de Android y las plantillas, que se instalan a
   mano (pasos en «Exportar a Android»).
4. **Los 12 probadores.** Se arranca pronto porque son 14 días de reloj.
5. **Contenido hasta 15–20 niveles.**
6. 🟡 **Ficha de tienda y formularios.** Recursos gráficos hechos y borrador de
   privacidad listo para revisar; falta publicarla y rellenar Play Console.

---

## Limpieza pendiente

- El fondo usa `Parallax2D`. El `ParallaxBackground` de antes dejaba de repetir
  con el viewport ensanchado y salía media pantalla en negro.
- **`scripts/cine_tomas.gd` no lo usa nadie**: ninguna escena, script ni prueba lo
  referencia. Aquí ponía justo lo contrario, que las SVG de `arte/laminas/` no se
  usaban desde que la intro pasó a `cine_tomas.gd`, y **era falso y peligroso**:
  `CineIntro.tscn` usa `cine.gd`, que carga esas láminas, y ahora también el final.
  Quien hubiera seguido esa nota habría roto las dos cinemáticas. Lo que sobra es
  `cine_tomas.gd`; las láminas (1,5 MB) no se tocan.
- El proyecto pesa unos 21 MB con la caché de Godot; `arte/` son 12 MB, de los que
  4,6 MB son sonido (las dos músicas van comprimidas en QOA al exportar) y 2,4 MB la
  hoja del fondo animado.

## Exportar a Android

El preset ya está en `export_presets.cfg`. Godot lo lee: al intentar exportar
desde este equipo, los únicos errores son lo que falta instalar.

**Lo que decide el preset, y por qué:**

| Opción | Valor | Por qué |
|---|---|---|
| Formato | **AAB** (`export_format=1`, comprobado en el código de Godot) | Google Play solo acepta AAB en apps nuevas |
| Compilación | **Gradle** | El AAB solo sale con Gradle |
| Arquitectura | **solo arm64-v8a** | Google exige 64 bits. Sin armeabi-v7a el paquete pesa la mitad y solo se quedan fuera teléfonos de 32 bits muy viejos |
| Paquete | **`com.joserico.pulso`** | ⚠️ **Es para siempre**: una vez subido a Play no se puede cambiar. Decídelo antes de la primera subida |
| Versión | código 1, nombre 1.0 | El **código hay que subirlo en cada envío** a Play, o lo rechaza |
| Permisos | **solo VIBRATE** | VIBRATE para la vibración al morir; **INTERNET apagado** (y el resto) |
| Pantalla | inmersiva | Esconde las barras del sistema mientras se juega |
| Copia de seguridad | apagada | El progreso no sale del teléfono, ni a la copia de Google |
| Excluido | `prueba/*` | Las 45 escenas de prueba no viajan al teléfono |
| Salida | `../exportar/PULSO.aab` | Fuera del proyecto, para que Godot no lo importe |

**INTERNET no se cuela solo en la versión que se publica:** el código de Godot
solo lo añade con la depuración remota (*remote debug* o *dumb client*), nunca
en una exportación de release.

**Icono:** el proyecto no tenía, así que en el teléfono habría salido el robot de
Godot. `../tsl04/build_iconos.py` saca de `retrato.png` el icono de 192 px (que es
también el del proyecto) y el **adaptativo** de Android, en dos piezas de 432 px:
TSL-04 sobre transparente y el halo de fondo. El lanzador recorta con su propia
máscara (círculo, gota, cuadrado), así que el personaje va dentro del círculo
seguro de 264 px: su silueta llega a 124 px del centro de 132 posibles.

**Orientación:** horizontal con sensor (`window/handheld/orientation=4`), para
que funcione con el teléfono girado hacia cualquiera de los dos lados.

**Lo que hay que instalar** (según la documentación de Godot 4.7):

1. **OpenJDK 17**.
2. **Android SDK**: Platform 35, Build-Tools 35.0.1, el NDK r28b y CMake 3.10 (lo
   más fácil, desde Android Studio).
3. En Godot: *Editor → Configuración del editor → Exportar → Android*, las rutas
   del SDK de Java y del SDK de Android.
4. En Godot: *Editor → Gestionar plantillas de exportación* (4.7.2), y después
   *Proyecto → Instalar plantilla de compilación de Android*.
5. El **keystore de producción**, una vez y para siempre:
   ```bash
   keytool -genkeypair -v -keystore pulso-release.keystore -alias pulso -keyalg RSA -keysize 2048 -validity 10000
   ```
   ⚠️ **Guárdalo fuera del proyecto y con copia.** Si se pierde, no se puede volver
   a actualizar el juego en Play.

**Exportar**, con la contraseña en variables de entorno y no en el archivo:

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/ruta/a/pulso-release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=pulso
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='...'
/Users/joserico/Documents/Archivo_Organizado/05_Software/Aplicaciones/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Android" ../exportar/PULSO.aab
```

Godot **reescribe `export_presets.cfg`** cada vez que se toca el preset en el
editor y se pierden sus comentarios; las razones están aquí por eso.

## Regenerar el sonido

```bash
python3 ../tsl04/build_sonido.py
cp ../tsl04/sonidos/*.wav arte/sonido/
```

## Regenerar el arte

Las láminas de la intro y el final:

```bash
cd ../tsl04
VARIANTE=0   SUF=a python3 laminas.py
VARIANTE=0.5 SUF=b python3 laminas.py
```

Escriben en `tsl04/laminas/`; hay que copiar `v*a.svg` y `v*b.svg` a `arte/laminas/`.
Las «a» salen idénticas a las del juego con `VARIANTE=0`. **Las «b» antiguas (1–18) no
se pueden reproducir con el script actual**: se probaron 215 desfases y ninguno las
da, así que se generaron con otra versión. Las nuevas (19–24) usan `0.5`, que da el
mismo hervor. **No copies las «b» 1–18 regeneradas** o cambiará el dibujo de la intro.


```bash
cd ../tsl04
/opt/homebrew/bin/blender -b --factory-startup --python build_elementos.py -- --render
python3 disena_niveles.py
```

Para el personaje:

```bash
cd ../tsl04
/opt/homebrew/bin/blender -b --factory-startup --python build_tsl04.py -- --render
```

Las doce animaciones son ~100 cuadros a 10 s cada uno: un cuarto de hora sin ver
nada. Para iterar sobre un ajuste de luz, **`--solo <animación>`** renderiza una
y reaprovecha los cuadros ya escritos de las demás para montar las hojas:

```bash
/opt/homebrew/bin/blender -b --factory-startup --python build_tsl04.py -- --render --solo correr
```

Y **`--glb`** saca el modelo en 3D para el menú principal (no renderiza nada, son
dos segundos). Hay que copiarlo al proyecto y que Godot lo importe:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python build_tsl04.py -- --glb
cp ../tsl04/tsl04.glb arte/tsl04/tsl04.glb
/Users/joserico/Documents/Archivo_Organizado/05_Software/Aplicaciones/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

Si se toca cualquier proporción del personaje, **hay que volver a exportarlo** o
el TSL-04 del menú se queda como estaba mientras los sprites cambian.

Y la música:

```bash
python3 ../tsl04/build_musica.py
cp ../tsl04/musica/circuito.wav arte/sonido/
```

Las hojas salen en `tsl04/hojas_*/` y **hay que copiarlas a mano** a
`pulso-godot/arte/`. Después hace falta reimportar, y aquí está la trampa:

```bash
/Users/joserico/Documents/Archivo_Organizado/05_Software/Aplicaciones/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

**Borrar `.godot/imported/` no basta.** Godot en headless NO reimporta al
ejecutar una escena: se queda sin los `.ctex`, las animaciones salen vacías y
las pruebas fallan con la animación en `''`. Hay que lanzar `--import`
explícitamente, y con ningún otro Godot vivo (`pgrep -x Godot`). Lo mismo con el
`.wav` de la música, cuyo destino es un `.sample`.

El `tsl04_spriteframes.tres` que genera el script **no se copia**: el del
proyecto lleva los UID que añade Godot, y mientras no cambien ni los cuadros ni
el ritmo, el que ya está sirve.
