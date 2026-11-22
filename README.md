# Paloma Retoma

Juego 3D low-poly hecho en Godot 4.7: sos una paloma en la plaza, juntás migas y armás tu bandada.

## Jugar

👉 **https://bissauli.github.io/Paloma-Retoma/**

Controles: WASD caminar · Espacio despegar/aletear · Shift picada · Click izquierdo picotear · Esc pausa.

## Versión Android

📱 Es el mismo link: abierto desde el navegador de un teléfono Android o iPhone, el juego pasa solo a la
versión táctil (con el teléfono acostado). El link viejo `/android/` redirige ahí.
Controles táctiles: joystick a la izquierda para caminar y volar · deslizá el dedo a la derecha para mirar ·
botones DESPEGAR/ALETEAR (mantener), PICADA (mantener), PICOTEAR y ARRULLAR · II pausa.

## Proyecto

- Código fuente Godot en la raíz (`project.godot`).
- Build web: el preset "Web" exporta CON hilos (y la extensión vacía `hilos.gdextension`, compilada desde `extension/`) para que Ziva (Share Web build) la suba con hilos. GitHub Pages no sirve las cabeceras que piden los hilos: `docs/` quedó con la build anterior sin hilos; para volver a exportar ahí hay que poner `thread_support=false` y `extensions_support=false` en el preset.
- Para regenerarla: Godot → Proyecto → Exportar → Web, o
  `godot --headless --export-release "Web" docs/index.html`.
- Antes de exportar, y después del último commit, actualizar la versión que muestra el menú (`v0.<commits> (autor del último commit)`):
  `godot --headless --path . --script tools/generar_version.gd`. En el editor se lee de git en el momento.
  Si la build se sube en el mismo commit que se va a hacer, agregar `-- siguiente` (escribe el número de ese commit).
- Una sola build para PC y teléfonos: en la web `Ajustes.movil` se activa con las features `web_android` /
  `web_ios` (controles táctiles de `ui/controles_tactiles.gd`; la versión de PC no los carga). Así el motor
  (`index.wasm`, lo que más pesa) se descarga y se cachea una sola vez.
- Pruebas automáticas en `tests/` (headless): `godot --headless --path . res://tests/test_vuelo.tscn`
  (también `test_bandada`, `test_enemigos` y `test_mapa_v31`; con `-- movil` corren con la física del teléfono).
- Modelos 3D (Blender, sin abrir Blender): `F:/blender.exe -b --factory-startup -P tools/blender/generar_ciudad.py`
  regenera el kit de la ciudad (`modelos/ciudad/`, con vistas previas en `previas/`; las piezas del mapa V3 están en
  `tools/blender/ciudad_v3.py`, que el generador ejecuta adentro) y `... -P tools/blender/generar_parque.py` el del parque
  (`modelos/parque/`). Los dos usan la paleta de `tools/blender/paleta.py`: si cambia, hay que correr los dos.
  Los perros y los gatos (con esqueleto y animaciones) salen de `... -P tools/blender/animales.py` (`modelos/animales/`;
  con `-- --previa` además dibuja una hoja con los cuadros de cada animación en `modelos/animales/previas/`).
  Las texturas de lajas de las veredas y la plaza salen de `python tools/generar_lajas.py` (con numpy).
  El mapa de la ciudad lo arma `world/ciudad.gd`; las capturas de cada zona salen con
  `godot --path . res://tests/captura_ciudad.tscn -- <carpeta> [vistas] [segundos]` (las vistas `iso_*` son las altas,
  como las referencias; los segundos de espera dejan que la gente, los chicos y los animales se pongan en movimiento).
- Cielo, día y noche y clima: `world/cielo.gd` (ver `DECISIONES.md`). En las versiones de prueba, **F6** cambia el
  clima y **F7** adelanta 2 horas. Capturas de cada hora y clima: `godot --path . res://tests/captura_cielo.tscn -- <carpeta>`;
  prueba headless: `test_cielo`. El estilo de los materiales está en `shaders/README_estilo_cozy.md`.
- Las mallas de nubes y del rayo (`modelos/cielo/`) se extraen de un pack con
  `godot --headless --path . -s res://tools/importar_cielo.gd -- <carpeta glb del pack>`.
- Rendimiento: `godot --path . res://tests/bench_rendimiento.tscn --disable-vsync` (con `-- movil` emula
  la versión para teléfonos). Las decisiones de optimización están en `DECISIONES.md`.
