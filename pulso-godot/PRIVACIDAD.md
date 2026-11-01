# PULSO — privacidad y formularios de Google Play

> **⚠️ BORRADOR. Jose tiene que revisarlo antes de usarlo.**
> No es asesoría legal. Está escrito a partir de una auditoría del código tal y
> como estaba el 15 de septiembre de 2026. **Hay que repetir la auditoría justo
> antes de enviar nada a Google**, porque exportar a Android puede añadir
> permisos que hoy no existen, y cualquier cambio del código puede invalidar lo
> que aquí se afirma.

---

## 1. La auditoría: qué se ha comprobado y cómo

Ninguna afirmación de este documento se hizo sin mirar el código. Estos son los
comandos, lanzados desde `pulso-godot/`, y lo que devolvieron.

| Qué se buscó | Comando | Resultado |
|---|---|---|
| Red de cualquier tipo | `grep -rnE "HTTPRequest\|HTTPClient\|WebSocket\|StreamPeerTCP\|PacketPeerUDP\|TCPServer\|UDPServer\|JavaScriptBridge\|MultiplayerPeer\|OS\.shell_open\|OS\.execute" scripts/ project.godot` | **Nada** |
| Identificadores y datos del sistema | `grep -rnE "get_unique_id\|get_model_name\|get_locale\|get_environment\|get_datetime\|screen_get\|get_processor" scripts/` | **Nada** |
| Anuncios, compras, analítica | `grep -rniwE "admob\|ads\|billing\|purchase\|analytics\|firebase\|crashlytics\|telemetry" scripts/ project.godot` | **Nada** |
| Plugins nativos | `ls -d addons android` | **No existen** |
| Preset de exportación | `grep permissions/ export_presets.cfg` | Existe: solo `vibrate=true`; `internet` y el resto, `false` |
| Escritura a disco | `grep -rnE "FileAccess\.open\(\|user://\|DirAccess\." scripts/` | Solo `scripts/guardado.gd` |

El de anuncios lleva `-w` (palabra completa) a propósito: sin él, «ads» casaría
con «llamadas» o «pisadas» en cuanto aparecieran en un comentario, y parecería
que hay anuncios donde no los hay.

### Lo único que se guarda

`scripts/guardado.gd:7` — un archivo, `user://progreso.json`, en el almacenamiento
privado de la app. Nunca sale del dispositivo: el juego no tiene código de red.

Contiene exactamente esto (`scripts/guardado.gd:41-66` y los ajustes):

| Campo | Qué es |
|---|---|
| `max_nivel` | el nivel más alto desbloqueado |
| `tiempos` | el mejor tiempo de cada nivel, en segundos |
| `fragmentos` | cuántos fragmentos se recogieron en cada nivel |
| `muertes` | un contador de muertes |
| `opciones` | `cerco_fijo`, `asistencia` y `vibracion`, verdadero o falso |
| `opciones.personaje` | qué celda se juega (`tsl04`, `tsl01`…) |
| `opciones.teclas` | las teclas que el jugador haya reasignado, como códigos de tecla (`"f75"` es la K). Solo las que difieren de fábrica |

Nada de eso identifica a una persona: no hay nombre, correo, cuenta, ubicación,
contactos, fotos ni identificador de dispositivo.

### Registros de Godot

`project.godot` no tiene ningún ajuste explícito de registro. Con los valores por
defecto de Godot 4, el registro a archivo va activado en escritorio y
**desactivado en móvil**. En cualquier caso esos registros son locales y no se
envían a ningún sitio. **Comprobar en el preset de exportación.**

---

## 2. Política de privacidad (español)

> Publicar esta sección en una URL pública. Rellenar los huecos marcados.

**Política de privacidad de PULSO**

Entrada en vigor: [RELLENAR: fecha de entrada en vigor]

PULSO es un videojuego creado por Jose Guadalupe Rico Moreno.

**PULSO no recoge, no almacena en servidores y no comparte ningún dato
personal.**

- El juego **no necesita conexión a internet** y no contiene código que envíe
  información fuera de tu dispositivo.
- **No hay anuncios, ni compras dentro de la aplicación, ni herramientas de
  analítica** o seguimiento de terceros.
- **No se crea ninguna cuenta** y no se pide ningún dato.
- Para guardar tu progreso, el juego escribe un pequeño archivo **solo en tu
  dispositivo**, dentro del espacio privado de la aplicación. Contiene tu nivel
  máximo, tus mejores tiempos, los fragmentos recogidos, un contador de intentos
  y tus ajustes (por ejemplo, si has activado la vibración o el modo asistencia,
  o qué teclas has cambiado).
  Ese archivo no identifica a nadie y se borra al desinstalar el juego.
- Si activas la vibración, el juego usa el vibrador del teléfono al perder una
  vida. No se usa para nada más.

Si Google Android realiza copias de seguridad automáticas de las aplicaciones en
tu cuenta de Google, ese proceso lo gestiona Android según tu configuración, no
el juego.

**Menores.** PULSO no recoge datos de nadie, tampoco de menores de edad.

**Cambios.** Si esta política cambia, la nueva versión se publicará en esta misma
página con su fecha.

**Contacto.** Para cualquier pregunta: [RELLENAR: correo de contacto]

---

## 3. Privacy policy (English)

**PULSO Privacy Policy**

Effective date: [RELLENAR: effective date]

PULSO is a video game made by Jose Guadalupe Rico Moreno.

**PULSO does not collect, store on servers, or share any personal data.**

- The game **does not need an internet connection** and contains no code that
  sends information off your device.
- There are **no ads, no in-app purchases, and no analytics** or third-party
  tracking tools.
- **No account is created** and no information is requested.
- To save your progress, the game writes a small file **only on your device**,
  inside the app's private storage. It holds your highest unlocked level, best
  times, collected fragments, an attempt counter and your settings (for example,
  whether vibration or assist mode is on, or which keys you have remapped). That file identifies no one and is
  removed when you uninstall the game.
- If vibration is enabled, the game uses the phone's vibration motor when you
  lose a life. It is not used for anything else.

If Android automatically backs up apps to your Google account, that process is
handled by Android according to your settings, not by the game.

**Children.** PULSO collects no data from anyone, including children.

**Changes.** If this policy changes, the new version will be posted on this same
page with its date.

**Contact.** For any questions: [RELLENAR: contact email]

---

## 4. Formulario «Seguridad de los datos» de Google Play

Respuestas sugeridas. Cada una lleva la evidencia que la sostiene.

| Pregunta | Respuesta sugerida | Evidencia |
|---|---|---|
| ¿La app recoge o comparte alguno de los tipos de datos de usuario requeridos? | **No** | Sin código de red (grep de la sección 1). Lo único guardado es `user://progreso.json`, que no sale del dispositivo. |
| ¿Se cifran los datos en tránsito? | No aplica: no hay datos en tránsito | Sin código de red |
| ¿Pueden los usuarios pedir que se borren sus datos? | No aplica: no se recogen datos. El progreso local se borra al desinstalar | `scripts/guardado.gd:7` escribe en `user://` |
| Ubicación, información personal, financiera, salud, mensajes, fotos, audio, archivos, calendario, contactos | **No** en todos | Ni un solo acceso en `scripts/` |
| Actividad en la app, información y rendimiento de la app, identificadores de dispositivo | **No** | Sin analítica, sin informes de fallos, sin `get_unique_id` |

**Sobre el progreso guardado.** Google considera «recogidos» los datos que salen
del dispositivo. Los datos que se procesan solo en el dispositivo y nunca se
envían no tienen que declararse. Por eso `progreso.json` no se declara.
**Confirmar esta interpretación en la ayuda de Play Console al rellenarlo**, que
es donde Google la mantiene al día.

---

## 5. Cuestionario de clasificación por edades (IARC)

Respuestas sugeridas, a partir de lo que realmente hay en el juego.

| Tema | Respuesta sugerida | Qué hay de verdad en el juego |
|---|---|---|
| **Violencia** | Fantástica o de caricatura, leve, sin sangre | El personaje es una bola de luz con cara. Al perder, se aplasta, pone ojos en X y **estalla en partículas de luz cian que se desvanecen** (`arte/tsl04/tsl04_muerte.png`). Acompaña un destello blanco, una sacudida de 3 px y una breve congelación (`scripts/efectos.gd`, `func muerte`). Los peligros son drones, láseres y pinchos dentro de una computadora. **No hay sangre, ni personas, ni armas reales, ni daño a seres vivos.** |
| Miedo | No | Estética de circuitos, sin sustos |
| Lenguaje soez | No | Textos revisables en `scripts/cine.gd` (cinemática) y los menús |
| Sexualidad o desnudez | No | — |
| Drogas, alcohol, tabaco | No | — |
| Apuestas o simulación de apuestas | No | — |
| **Interacción entre usuarios** / chat | **No** | Sin red |
| **Compartir ubicación** | **No** | Sin acceso a ubicación |
| **Compras digitales** | **No** | Sin compras integradas |
| **Anuncios** | **No** | Sin SDK de anuncios |

Con estas respuestas lo esperable es la clasificación más baja (del tipo PEGI 3 o
ESRB Everyone), pero **la decide IARC, no este documento.**

### Una decisión que es de Jose: el público objetivo

En Play Console hay que elegir las edades del público. El juego tiene un
personaje entrañable y eso puede atraer a niños. **Si se marca cualquier franja
menor de 13 años, la app entra en la Política de Familias de Google**, que es más
estricta (revisión del contenido, requisitos extra de privacidad y de anuncios).
No es malo, pero hay que decidirlo sabiendo eso.

---

## 6. Cómo publicar la política en una URL gratis (GitHub Pages)

1. Crear en GitHub un repositorio **público**, por ejemplo `pulso-privacidad`, y
   subir un archivo `index.md` con la sección 2 (y la 3 debajo).
2. En el repositorio: **Settings → Pages → Source: Deploy from a branch**, rama
   `main`, carpeta `/ (root)`. Guardar.
3. Al cabo de un minuto la página queda en
   `https://<usuario>.github.io/pulso-privacidad/`. Esa es la URL que se pega en
   Play Console. Abrirla desde el móvil para comprobar que se ve.

---

## 7. Antes de enviar: lo que hay que volver a mirar

- [ ] **Repetir los `grep` de la sección 1.** Si alguien añadió red, anuncios o
      analítica, todo este documento deja de valer.
- [ ] **Permisos del preset de Android.** `export_presets.cfg` ya existe con
      `permissions/vibrate=true` y todos los demás en `false`, `internet`
      incluido. Comprobar que sigue así antes de cada envío, y mirar el
      manifiesto del AAB final:
      - **`VIBRATE` hace falta**, porque el juego vibra al morir
        (`scripts/efectos.gd`, `Input.vibrate_handheld`). Sin él, la vibración
        no funciona en el teléfono.
      - **`INTERNET` NO debe estar marcado.** El juego no lo necesita, y si se
        marca Google puede pedir explicaciones y la política de arriba dejaría
        de ser del todo cierta.
      - Revisar que no haya ningún otro permiso marcado.
- [ ] **Registro a archivo en móvil**: comprobar que sigue desactivado.
- [ ] Rellenar los tres huecos `[RELLENAR: ...]` y publicar en la URL.
