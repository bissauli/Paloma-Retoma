# Decisiones de diseño — Palomas de Mayo

Elegí siempre la opción más simple y divertida cuando algo era ambiguo. Las anoto acá.

## Técnicas
- **Godot 4.7.2**, renderer *GL Compatibility* y física **Jolt** (ya venían en la carpeta). Mantengo el addon Beckett (MCP) tal cual.
- **Interpolación de física activada**: la física corre a 60 Hz y la cámara se mueve en `_process` leyendo la posición interpolada. Así no hay tirones en monitores de 144 Hz.
- **El mundo se arma por código** (`world/plaza.gd` + `world/construir.gd`) con BoxMesh/CylinderMesh/SphereMesh/PrismMesh y StaticBody3D. Es más fácil de ajustar que cientos de nodos CSG escritos a mano y rinde mejor (CSG recalcula mallas). Los materiales se cachean por color.
- **Audio**: en vez de un `AudioStreamGenerator` en streaming, cada sonido se sintetiza una vez al arrancar en un `AudioStreamWAV`, que es más simple y gasta menos CPU. Si ponés un `.wav`/`.ogg` con el mismo nombre en `audio/`, se usa ese archivo en su lugar.
- Los umbrales y la economía están en `config.gd`. Los valores de movimiento son `@export` en `player/paloma.gd` (se tocan desde el inspector de `player/paloma.tscn`).

## Vuelo (fase 2)
- **Controles relativos a la cámara**, igual en el suelo que en el aire. Es lo más intuitivo con mouse y WASD.
- **Espacio en el suelo** = despegar (con un saltito hacia adelante). **Espacio mantenido en el aire** = aletear y subir (gasta stamina). **Soltarlo** = planear con caída lenta.
- **Sin stamina** no podés aletear y caés más rápido, pero nunca a plomo.
- **Picada (Shift)**: acelera hacia donde mirás y baja rápido; el FOV se abre y la cámara se aleja. **Al soltar Shift**, parte de la velocidad se convierte en altura (un "swoosh" hacia arriba). Así la picada sirve para cruzar el mapa rápido y no sólo para bajar.
- **Caerse de una cornisa** pasa a planeo automáticamente, sin gastar el despegue.
- **Aterrizaje automático** al tocar cualquier superficie transitable (piso, techos, cornisas, balcón). Las paredes sólo te frenan.
- La stamina se recarga **lento caminando** y **rápido comiendo migas**, para que las migas importen.
- La protagonista es un poco más flaca que las demás, tiene un mechón despeinado y el cuello violeta. Las NPC lo tienen verde.

## Mapa (fase 3)
- El mapa se arma en `world/plaza.gd` (cielo, piso, límites, zonas) y `world/edificios.gd` (cada edificio). Coordenadas: X = este, Z = sur. El mapa mide 120 x 80 m.
- **Pirámide de Mayo** en el centro = NIDO. Arriba flota "🕊 x N" con la bandada y abajo la comida acumulada.
- **Cabildo** al oeste, con galería, cornisa, techo de tejas y torre. **Catedral** al norte, con pórtico, frontón y escalinata (con una rampa invisible para poder subirla caminando).
- **Cafés al sur** con nombres inventados: "Café La Medialuna Feliz", "Confitería El Buen Mozo", "Bar Los Vencejos" y "Banco Austral Imaginario". Toldos para posarse y mesas en la vereda.
- **Subte "Línea Ñ"** al noreste, para que no sea ninguna línea real.
- **Casa Rosada** al este, con vallas (no tienen hueco: hay que entrar volando) y el **balcón** en el cuerpo central, a 7 m de altura.
- Las copas de los jacarandás tienen colisión: te podés posar en los árboles. Los toldos, cornisas, techos y bancos también sirven para posarse.
- La figura de la cima de la Pirámide es abstracta (una esfera), para mantener todo low-poly.

## Comida y stamina (fase 4)
- **Migas**: aparecen solas de a poco en "generadores" (Cabildo, Catedral, subte, centro). Al comerlas recuperás 18 de stamina y sumás 1 de comida. Así el tutorial ya enseña a reclutar.
- **Medialunas y papas** en las mesas de los cafés, y **facturas** cerca del subte. Las llevás en el pico (vas al 60% de velocidad y subís más lento) y en el nido suman 4 (medialuna) o 3 (papa/factura). Reaparecen a los 30-40 s.
- **Choripán** en el carrito "El Chori Feliz" sobre la avenida. Con 5 palomas o más la bandada lo levanta y suma 12 de comida directo, sin tener que llevarlo. Si no te alcanza la bandada, te avisa.
- Sólo llevás una cosa por vez. La comida "pesada" flota, gira y tiene un brillito para que se vea de lejos.

## Bandada (fase 5)
- **Reclutar cuesta 1 de comida por paloma.** Un arrullo recluta a todas las palomas sueltas que haya en 7 m, de la más cercana a la más lejana, mientras tengas comida. Cada una muestra un corazón.
- Hay unas 48 palomas sueltas al empezar, repartidas en seis zonas (la Catedral es la que más tiene). Si quedan menos de 14 sueltas, llegan palomas nuevas volando desde los bordes del mapa.
- Cada paloma de la bandada tiene un "lugar" propio alrededor tuyo y se queda un poco atrás cuando vas rápido. Si aterrizás, aterrizan a tu alrededor y caminan.
- **Boids**: separación, alineación, cohesión y seguir a la jugadora. Las que están a más de 25 m se actualizan 1 de cada 3 frames. Las NPC no usan física: miden el piso con un rayo cada 0,3-0,6 s. De lejos no se dibujan los detalles chicos (ojos, patas, pico).
- Cuando perdés palomas se dispersan las más cercanas al peligro. Vuelan lejos, eligen una zona al azar y aterrizan ahí, y las podés volver a reclutar.
- Hay palomas blancas y marrones además de las grises, y cada una tiene un nombre (Carlos, La Tana, El Ruso, Coqui...) para los créditos.

## Humanos y enemigos (fase 6)
- Todos comparten `enemies/modelo_humano.gd`: cápsula de color, cabeza sin cara, brazos que se balancean y un rebote al caminar. Los accesorios (gorra, sombrero, morrión con penacho, moño y bandeja de mozo) se hacen con primitivas.
- `enemies/gente.gd` ubica a todos en los puntos que marca la plaza y maneja las oleadas del subte.
- **Turistas y grupo escolar** (Cabildo): pasean y tiran migas. Con **15+ palomas**, si te acercás salen corriendo y el 75% de las veces se les cae una papa o factura.
- **Señoras** sentadas en los bancos de la Catedral: tiran migas cada 3-5 s. Zona segura, sin enemigos.
- **Oficinistas**: salen del subte en oleadas de 4 a 7 cada 28 s, caminan hasta el borde del mapa y a la mitad se les cae una factura.
- **Nene** (centro de la plaza): te corre si estás en el piso o volando a menos de ~2 m, más rápido de lo que caminás pero más lento de lo que volás. Se cansa a los 6 s. Si te alcanza **dispersa el 25% de la bandada** y te hace volar, pero **no** te manda al nido.
- **Mozo** (cafés): patrulla la vereda con cono de visión. Si te ve cerca de las mesas, silba y corre. Si te alcanza te espanta (salís volando hacia la plaza) y **se te cae la comida** que llevabas. No perdés palomas.
- **Granaderos** (2, frente a la Casa Rosada): tienen el **cono de visión dibujado en el piso** (amarillo; rojo cuando te están viendo). Si te ven pasando las vallas sin 30 palomas, en 0,6 s silban y **volvés al nido perdiendo 2 palomas**. Con 30 o más se distraen mirando la bandada (aparece "♪") y el cono desaparece.
- **Halcón**: aparece al llegar a 15 palomas y da vueltas a 27 m. Si volás **por encima de 7 m sin nada arriba** (árbol, techo, galería), chilla, avisa con 1,4 s de margen y se tira en picada. Zafás aterrizando, bajando o escondiéndote. Si te atrapa **perdés 3 palomas y volvés al nido**.
- Después de que te atrapan tenés **3 s de invulnerabilidad**, para que no te encadenen castigos.

## Interfaz, tutorial y victoria (fase 7)
- **HUD** (`ui/hud.tscn`): arriba a la izquierda "🕊 x N" (cambia de color a los 15 y a los 30), la barra de stamina (se pone roja cuando queda poca), la comida y lo que llevás en el pico. Arriba al centro el objetivo en una línea, los mensajes en el centro y los controles abajo. Cuando te atrapan hay un fundido con un texto.
- **Pausa** (`ui/pausa.tscn`, Esc): Continuar, Reiniciar y Salir al título.
- **Tutorial** (`world/tutorial.gd`): un cartel flotante sobre la paloma que avanza solo a medida que hacés cada cosa (caminar, picotear, despegar, picada, arrullar) y termina con "andá a la Catedral". Cada paso tiene un tiempo máximo para no trabarse, y si te alejás mucho del Cabildo se da por terminado. Dura unos 30 s.
- **Victoria**: aterrizar en el balcón con 30 o más palomas. Si llegás con menos, te avisa cuántas faltan (y los granaderos te ven). En la cinemática la cámara barre la plaza frente a la Casa Rosada, la bandada se reparte entre el balcón y la plaza, llegan 50 palomas más y todas festejan arrullando. Aparece "¡LA PLAZA ES NUESTRA!" y después los créditos con nombres de palomas (siempre arrancan con Carlos, La Tana, El Ruso y Coqui).
- Las escenas de UI arman parte de sus controles por código (el HUD es todo por código) para ajustar los valores en un solo lugar.

## Ciclo de día y pulido (fase 8)
- **Ciclo de día**: va de la mañana al atardecer según lo que más haya avanzado, el tiempo (14 min) o la bandada (con 30 palomas ya es casi atardecer). Cambian el ángulo y el color del sol, el cielo, la niebla y la luz ambiente.
- **Pantalla de título en 3D**: la plaza de fondo con una cámara que gira despacio y palomas picoteando.
- Arreglado el z-fighting de los canteros: pasto y borde ya no tienen la tapa a la misma altura.
- Pruebas automáticas en `tests/` (`test_vuelo`, `test_bandada`, `test_enemigos`, y `captura_final` como prueba de punta a punta de la victoria). Se corren headless.
- `tools/configurar_input.gd` vuelve a aplicar el Input Map y los autoloads desde el editor, por si alguna vez se pisa `project.godot`.
