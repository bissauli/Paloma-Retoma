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
- Build web en `docs/` (exportado con el preset "Web", sin threads para que funcione en GitHub Pages).
- Para regenerarla: Godot → Proyecto → Exportar → Web, o
  `godot --headless --export-release "Web" docs/index.html`.
- Antes de exportar, y después del último commit, actualizar la versión que muestra el menú (`v0.<commits> (autor del último commit)`):
  `godot --headless --path . --script tools/generar_version.gd`. En el editor se lee de git en el momento.
- Una sola build para PC y teléfonos: en la web `Ajustes.movil` se activa con las features `web_android` /
  `web_ios` (controles táctiles de `ui/controles_tactiles.gd`; la versión de PC no los carga). Así el motor
  (`index.wasm`, lo que más pesa) se descarga y se cachea una sola vez.
- Pruebas automáticas en `tests/` (headless): `godot --headless --path . res://tests/test_vuelo.tscn`
  (también `test_bandada` y `test_enemigos`; con `-- movil` corren con la física del teléfono).
- Rendimiento: `godot --path . res://tests/bench_rendimiento.tscn --disable-vsync` (con `-- movil` emula
  la versión para teléfonos). Las decisiones de optimización están en `DECISIONES.md`.
