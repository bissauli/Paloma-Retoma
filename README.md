# Paloma Retoma

Juego 3D low-poly hecho en Godot 4.7: sos una paloma en la plaza, juntás migas y armás tu bandada.

## Jugar

👉 **https://bissauli.github.io/Paloma-Retoma/**

Controles: WASD caminar · Espacio despegar/aletear · Shift picada · Click izquierdo picotear · Esc pausa.

## Versión Android

📱 **https://bissauli.github.io/Paloma-Retoma/android/**

Se juega desde el navegador del teléfono, igual que la de PC (con el teléfono acostado).
Controles táctiles: joystick a la izquierda para caminar y volar · deslizá el dedo a la derecha para mirar ·
botones DESPEGAR/ALETEAR (mantener), PICADA (mantener), PICOTEAR y ARRULLAR · II pausa.

## Proyecto

- Código fuente Godot en la raíz (`project.godot`).
- Build web en `docs/` (exportado con el preset "Web", sin threads para que funcione en GitHub Pages).
- Para regenerarla: Godot → Proyecto → Exportar → Web, o
  `godot --headless --export-release "Web" docs/index.html`.
- Build para teléfonos en `docs/android/` (preset "Web Android", con la feature `movil` que activa los
  controles táctiles de `ui/controles_tactiles.gd`; la versión de PC no los carga):
  `godot --headless --export-release "Web Android" docs/android/index.html`.
