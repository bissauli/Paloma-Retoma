# Decisiones de diseño — Paloma Retoma

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
- La protagonista usa la paloma "Original" (gris lavanda). Las NPC usan las otras variantes de color, así se la distingue en la bandada (ver "Modelo de paloma").

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
- **Choques**: las palomas NPC no se atraviesan. Como no usan física, `flock/bandada.gd` las separa a mano cada cuadro con una grilla de 1 m: entre ellas se empujan las dos (radio 0,2 m), y contra la jugadora o la gente se corre sólo la paloma. La gente tiene además una cápsula física (capa 3) para que la jugadora choque contra ella en vez de atravesarla. Las palomas NPC siguen midiendo el piso sólo contra la capa 1.
- **Boids**: separación, alineación, cohesión y seguir a la jugadora. Las que están a más de 25 m se actualizan 1 de cada 3 frames. Las NPC no usan física: miden el piso con un rayo cada 0,3-0,6 s.
- Cuando perdés palomas se dispersan las más cercanas al peligro. Vuelan lejos, eligen una zona al azar y aterrizan ahí, y las podés volver a reclutar.
- Las palomas NPC salen en seis colores al azar (gris, oscura, marrón, canela, manchada y blanca), y cada una tiene un nombre (Carlos, La Tana, El Ruso, Coqui...) para los créditos.

## Humanos y enemigos (fase 6)
- Todos comparten `enemies/modelo_humano.gd`: cápsula de color, cabeza sin cara, brazos que se balancean y un rebote al caminar. Los accesorios (gorra, sombrero, morrión con penacho, moño y bandeja de mozo) se hacen con primitivas.
- `enemies/gente.gd` ubica a todos en los puntos que marca la plaza y maneja las oleadas del subte.
- **Turistas y grupo escolar** (Cabildo): pasean y tiran migas. Con **15+ palomas**, si te acercás salen corriendo y el 75% de las veces se les cae una papa o factura.
- **Señoras** sentadas en los bancos de la Catedral: tiran migas cada 3-5 s. Zona segura, sin enemigos.
- **Oficinistas**: salen del subte en oleadas de 4 a 7 cada 28 s, caminan hasta el borde del mapa y a la mitad se les cae una factura.
- **Nene** (centro de la plaza): te corre si estás en el piso o volando a menos de ~2 m, más rápido de lo que caminás pero más lento de lo que volás. Se cansa a los 6 s. Si te alcanza **dispersa el 25% de la bandada** y te hace volar, pero **no** te manda al nido.
- **Mozo** (cafés): patrulla la vereda con cono de visión. Si te ve cerca de las mesas, silba y corre. Si te alcanza te espanta (salís volando hacia la plaza) y **se te cae la comida** que llevabas. No perdés palomas. Después de una persecución tarda 3 s en poder volver a verte, para que no silbe en bucle.
- Los enemigos que la escena ubica después de `add_child` (mozo, nene) toman su línea de patrulla o su zona en el primer cuadro de física, no en `_ready` (ahí todavía están en el origen).
- **Granaderos** (2, frente a la Casa Rosada): tienen el **cono de visión dibujado en el piso** (amarillo; rojo cuando te están viendo). Si te ven pasando las vallas sin 30 palomas, en 0,6 s silban y **volvés al nido perdiendo 2 palomas**. Con 30 o más se distraen mirando la bandada (aparece "♪") y el cono desaparece.
- **Halcón**: aparece al llegar a 15 palomas y da vueltas a 27 m. Si volás **por encima de 7 m sin nada arriba** (árbol, techo, galería), chilla, avisa con 1,4 s de margen y se tira en picada. Zafás aterrizando, bajando o escondiéndote. Si te atrapa **perdés 3 palomas y volvés al nido**.
- Después de que te atrapan tenés **3 s de invulnerabilidad**, para que no te encadenen castigos.

## Interfaz, tutorial y victoria (fase 7)
- **HUD** (`ui/hud.tscn`): arriba a la izquierda "🕊 x N" (cambia de color a los 15 y a los 30), la barra de stamina (se pone roja cuando queda poca), la comida y lo que llevás en el pico. Arriba al centro el objetivo en una línea, los mensajes en el centro y los controles abajo. Cuando te atrapan hay un fundido con un texto.
- **Pausa** (`ui/pausa.tscn`, Esc): Continuar, Reiniciar, Opciones y Salir al menú (guarda la partida).
- **Tutorial** (`world/tutorial.gd`): un cartel flotante sobre la paloma que avanza solo a medida que hacés cada cosa (caminar, picotear, despegar, picada, arrullar) y termina con "andá a la Catedral". Cada paso tiene un tiempo máximo para no trabarse, y si te alejás mucho del Cabildo se da por terminado. Dura unos 30 s.
- **Victoria**: aterrizar en el balcón con 30 o más palomas. Si llegás con menos, te avisa cuántas faltan (y los granaderos te ven). En la cinemática la cámara barre la plaza frente a la Casa Rosada, la bandada se reparte entre el balcón y la plaza, llegan 50 palomas más y todas festejan arrullando. Aparece "¡LA PLAZA ES NUESTRA!" y después los créditos con nombres de palomas (siempre arrancan con Carlos, La Tana, El Ruso y Coqui).
- Las escenas de UI arman parte de sus controles por código (el HUD es todo por código) para ajustar los valores en un solo lugar.

## Ciclo de día y pulido (fase 8)
- **Ciclo de día**: va de la mañana al atardecer según lo que más haya avanzado, el tiempo (14 min) o la bandada (con 30 palomas ya es casi atardecer). Cambian el ángulo y el color del sol, el cielo, la niebla y la luz ambiente.
- **Pantalla de título en 3D**: la plaza de fondo con una cámara que gira despacio y palomas picoteando (reemplazada después por el menú principal dentro de `main.tscn`, ver más abajo).
- Arreglado el z-fighting de los canteros: pasto y borde ya no tienen la tapa a la misma altura.
- Pruebas automáticas en `tests/` (`test_vuelo`, `test_bandada`, `test_enemigos`, y `captura_final` como prueba de punta a punta de la victoria). Se corren headless.
- `tools/configurar_input.gd` vuelve a aplicar el Input Map y los autoloads desde el editor, por si alguna vez se pisa `project.godot`.

## Modelo de paloma (Blender)
- Todas las palomas usan el mismo modelo blocky hecho en Blender: una malla con textura pixel-art de 128x128, un esqueleto de 8 huesos (`root`, `body`, `head`, `wing_L`, `wing_R`, `tail`, `leg_L`, `leg_R`) y 7 animaciones: `Idle`, `Walk`, `Fly`, `Glide`, `Dive` (en bucle), y `Peck` y `Coo` (una sola vez). Godot pone en bucle solo las que en Blender terminan en `_loop` y les saca ese sufijo al importar.
- Las variantes de color son el mismo modelo con otra paleta en la textura: cada color original se cambia 1 a 1, así la malla, los huesos y las animaciones son idénticos. Hay un GLB por variante en `modelos/paloma/`: `Paloma.glb` (la de la jugadora) y `Paloma_Gris`, `Paloma_Blanca`, `Paloma_Marron`, `Paloma_Oscura`, `Paloma_Canela` y `Paloma_Manchada`.
- `player/modelo_paloma.gd` instancia el GLB de la variante, lo gira 180° (el GLB mira a +Z y el juego espera -Z) y elige la animación según el modo: suelo (`Idle` o `Walk`, más rápida cuanto más camina), aleteo (`Fly`), planeo (`Glide`) y picada (`Dive`). Picotear y arrullar son animaciones de un uso, y en el aire no se reproducen. La comida que se lleva cuelga de un `BoneAttachment3D` en el hueso de la cabeza.
- Las probabilidades de cada color para las NPC están en `ModeloPaloma.PESOS_NPC`.
- Las texturas se importan sin pérdida (`compress/mode=0`) y con filtro "nearest", para que el pixel-art no se vea borroso ni cambie de color.
- Con 110 palomas rinde igual que el modelo anterior de primitivas (unos 7,4 ms por cuadro contra 7,9 ms en una RX 5500 XT). Lo que más cuesta son las sombras.
- Los carteles con nombre (`Construir.cartel`) son de una sola cara: un Label3D se lee de frente desde +Z, así que los que miran hacia -Z van girados 180°. Desde atrás no se ven en espejo.
- Los archivos fuente (`Paloma.blend`, las texturas y las vistas previas) están fuera del repo, en la carpeta "Paloma 3D" del escritorio.

## Menú principal (rediseño: blanco y cyan, en el mundo 3D)
- **El juego se llama "Paloma Retoma"** (nombre de la ventana y de la pestaña del navegador).
- **La escena principal pasa a ser `main.tscn`**: el mundo, la gente y la paloma de la jugadora ya están cargados detrás del menú. El menú es una capa más de esa escena (`ui/menu/menu_principal.tscn`), así que empezar a jugar no cambia de escena ni funde a negro. `ui/titulo.tscn` (el título pixel-art) se borró.
- **Estructura**: `Main` > `Plaza`, `Paloma`, `CamaraMenu` (Camera3D, `ui/menu/camara_menu.gd`), `Bandada`, `Gente`, `Tutorial`, `HUD`, `Pausa`, `Victoria` y `MenuPrincipal` (CanvasLayer 10) > `Raiz` (con el tema) > `Velo` (degradé oscuro a la derecha), `Titulo` ("PALOMA / RETOMA" y una raya fina) y `Botones` (cada uno en `Fila` > `Desliz` > botón, para que la entrada deslizada y el estirón del foco no se pisen). Opciones y Cargar partida son pantallas que arma el script (`PantallaMenu`).
- **Paleta**: toda la interfaz en blanco (textos, títulos, iconos, bordes de foco, deslizadores y casillas) y los recuadros en cyan azulado translúcido (#3FB8D6 al 55 % con un borde cyan más saturado). Con el mouse encima o con foco, el cyan se aclara y aparece un borde blanco fino. Sombras oscuras suaves para leer sobre el 3D. Nada de naranja en la interfaz.
- **Tema**: `ui/tema/tema_paloma.tres`, generado por `tools/generar_tema.gd` (`godot --headless --path . -s res://tools/generar_tema.gd`). Los colores y tamaños están ahí, en un solo lugar; si se edita el .tres a mano en el editor, el generador lo pisa la próxima vez. Variaciones: `BotonMenu`, `BotonVolver`, `TituloJuego`, `TituloPantalla`, `Seccion`, `Etiqueta`, `Valor`, `TextoChico`, `TextoTarjeta`, `FilaOpcion`/`FilaOpcionFoco`, `Tarjeta` y `Aviso`. La pausa usa el mismo tema.
- **Tipografías (OFL, en `ui/tema/fuentes/` con sus licencias)**: Bebas Neue para los títulos (condensada y gruesa), Oswald Light para los títulos de sección y Montserrat (variable, peso 400-500) con mucho espaciado entre letras para botones y etiquetas, todo en mayúsculas. Los iconos (perilla del deslizador, casillas, interruptor, flecha y puntos de la lista) son SVG importados como DPITexture, así se ven nítidos a cualquier resolución.
- **Botones** (como barras translúcidas): el borde izquierdo en diagonal, el texto alineado a la derecha y la barra sigue más allá del borde de la pantalla. Con foco la barra crece 26 px hacia la izquierda. Se manejan con mouse, teclado o mando (arriba/abajo dan la vuelta; si se pierde el foco, las flechas lo recuperan). SALIR no aparece en la versión web (dejaría la pestaña congelada).
- **Pantallas de Opciones y Cargar**: título grande y VOLVER abajo a la izquierda, el contenido en una columna a la derecha con secciones centradas. Opciones tiene AUDIO (General, Música, Voz, Efectos, Silenciar todo), PANTALLA (Brillo, Calidad, Resolución, Límite de FPS, Pantalla completa) y CONTROLES (Sensibilidad, Invertir eje Y): se agregaron los volúmenes por bus y el brillo, y se mantuvo todo lo que ya había. La fila con foco se resalta con una franja cyan y una raya blanca. Esc o el botón B del mando vuelven.
- **Buses de audio** (`default_bus_layout.tres`): Musica (el murmullo de la plaza y, si algún día se agrega, `audio/musica.ogg`), Voces (arrullos, el grito del nene, el chillido del halcón) y Efectos (todo lo demás). Por ahora no hay música, así que el volumen de Música regula el ambiente. Ajustes crea los buses si faltan.
- **Brillo**: usa los ajustes del Environment de la plaza (`adjustment_brightness`, de 60 % a 140 %). Sólo cambia el 3D: la interfaz queda igual. Funciona en el renderer Compatibility.
- **Guardar y continuar**: hay un solo lugar de guardado (`user://partida.cfg`). Se guarda solo cada 20 s, al salir al menú desde la pausa y al cerrar la ventana. Guarda bandada, comida, tiempo jugado, momento del día, tutorial y avisos ya mostrados. CONTINUAR sólo aparece si hay partida guardada. CARGAR PARTIDA muestra la partida (palomas, comida, tiempo y fecha) y deja cargarla o borrarla (borrar pide confirmar). Al ganar se borra. NUEVA PARTIDA no borra la guardada enseguida: la pisa el primer autoguardado. Al continuar, la paloma arranca en el Cabildo, la bandada guardada vuelve volando (las sueltas más cercanas y, si faltan, llegan desde los bordes) y el día avanza de a poco hasta donde estaba. Lo que llevabas en el pico no se guarda. Las pruebas automáticas no guardan nada.
- **La paloma del menú es el modelo 3D** (la misma `Paloma.glb` de la jugadora), no los sprites 2D: así es la misma paloma que después se juega y la cámara puede pasar del menú al juego sin cortes. Con los sprites habría que haber hecho un fundido o un cambio de escena. Los sprites, sus frames y las piezas pixel-art del menú viejo se borraron (no los usaba nada más).
- **Gestos de la paloma** (`player/gestos_paloma.gd`, un `SkeletonModifier3D` sobre el esqueleto del GLB): gira la cabeza a tirones cortos con un resorte apenas subamortiguado, como las palomas de verdad. Cada 0,6-2,6 s elige al azar mirar a la cámara de frente, de costado con un solo ojo (con la cabeza inclinada), alrededor, arriba o al piso. Parpadea cada 2-5,5 s (a veces doble, y muchas veces al girar mucho la cabeza), picotea cada 6-14 s y arrulla bajito cada 16-32 s. Los párpados son dos cajitas con el mismo material del modelo (todas sus UV apuntan al gris de la cabeza) que siguen la pose final de la cabeza (un `BoneAttachment3D` toma la pose de antes del modificador y quedaban mal puestas). Al empezar la partida los gestos se apagan de a poco y se borran.
- **Cámara del menú**: primer plano de la paloma a 1,6 m, un poco de costado (-24°), a 30 cm del piso y con un vaivén muy suave. El encuadre corre la vista para que el pecho de la paloma quede abajo a la izquierda (en coordenadas de pantalla, así funciona igual en 16:9, 4:3 o ultra ancho) y la interfaz no le tape la cabeza.
- **Transición al juego**: la paloma da un saltito con aleteo, el menú se va (los botones salen hacia la derecha) y la cámara del menú vuela hasta la cámara orbital del juego en 2,1 s con un ease in-out: interpola ángulo, altura y distancia alrededor de la paloma (orbita, nunca la atraviesa), el punto al que mira, el encuadre y el FOV, y en los últimos cuadros calza exacto con la cámara del juego y le pasa el mando. El control vuelve al 70 % de la transición y el HUD aparece al final. El tutorial arranca cuando la paloma vuelve a apoyarse.
- **El punto de inicio se corrió 3 m al sur** (a (-36, 0, 3)): en (-36, 0, 0) quedaba bajo la sombra de un jacarandá a la mañana y en el menú la paloma se veía apagada.
- Mientras está el menú, ninguna paloma suelta puede quedarse entre la cámara y la jugadora ni pegada a ella (`Bandada.zona_libre`), nadie la puede atrapar y la pausa no se abre. Reiniciar (desde la pausa) arranca directo a jugar, sin menú.
- Del menú viejo se sacaron el botón de Sonido (está "Silenciar todo" en Opciones) y el "?" de ayuda (los controles están en la pausa y el tutorial los enseña).
- Las referencias visuales que guiaron el diseño están en `docs/referencias/` (con `.gdignore`: Godot no las importa ni las exporta). De ellas sólo se tomó la tipografía, la disposición y la forma de los controles; ningún asset.
- Pruebas: `tests/test_menu.tscn` (headless: menú encima del mundo, transición continua y con la cámara del juego al final, continuar con la bandada y la comida guardadas, buses y brillo) y `tests/captura_menu.tscn` (capturas del menú, el foco, Opciones, Cargar, la transición y la pausa; se le pasa la carpeta y un prefijo).

## Arreglos y agregados (noviembre 2026)
- **Palomas NPC contra el mundo**: siguen sin física, pero cada movimiento (y cada empujón entre palomas) se chequea con un rayo contra la capa 1 a 30 cm del piso (`PalomaNPC.mover_con_choques`). Si pegan contra una pared se deslizan a lo largo; si pegan contra algo transitable (techo, rampa, cornisa) quedan apoyadas encima. A 30 cm se suben solas los escalones y cordones bajos.
- **Escalinata de la Catedral**: 10 escalones macizos de 20 cm (apoyados en el piso, sin huecos) que llegan hasta la plataforma. La rampa invisible estaba al revés (subía hacia la plaza): ahora pasa por la mitad de cada contrahuella, y la colisión de cada escalón queda 10 cm por debajo, así de costado también es sólida.
- **Letreros**: los nombres de los cafés, la librería y la aseguradora van sobre una tabla pegada a la fachada (`Construir.letrero`), encima del toldo. "CABILDO" va pintado en la torre, debajo del reloj (que antes quedaba adentro de la torre).
- **Stamina**: en el suelo se recarga a 7/s (antes 4/s). Las migas siguen siendo lo más rápido.
- **Opciones en la pausa**: la misma pantalla de Opciones del menú principal, con un botón "Opciones" en la pausa. La sensibilidad y el eje invertido se leen en cada movimiento del mouse, así que se aplican al instante.
- **Calidad** (Opciones > Pantalla): Baja / Media / Alta. Cambian la distancia de las sombras (70 / 140 / 240 m), los cortes de la sombra del sol (1 / 2 / 4), el filtro suave y el MSAA (no / 2x / 4x). En la compu arranca en Alta y en la web en Media. En una RX 5500 XT, la vista aérea de todo el mapa (el peor caso) pasa de ~6 ms por cuadro (antes, con sombras a 90 m) a ~7 ms en Baja y ~10,5 ms en Alta. Con la cámara a la altura de la paloma la diferencia es de ~1 ms.
- **Resolución**: en ventana cambia el tamaño de la ventana (y la centra). En pantalla completa y en la web no se puede cambiar el tamaño, así que la resolución elegida baja la resolución con la que se dibuja el 3D (`scaling_3d_scale`); la interfaz queda nítida.
- **Migas que brillan**: un destello chiquito que aparece de a poco cuando la paloma está a menos de 6 m, titila y desaparece al alejarse. De lejos no se ve, para no llenar la plaza de brillos.
- **Líneas de viento** (`player/viento.gd`): rayitas blancas finas pegadas a la cámara que pasan al costado cuando volás a más de ~7 m/s, y más marcadas en la picada. En el suelo no aparecen.
- **Comensales**: llegan caminando por la vereda (entre las mesas y las vidrieras), se sientan en una silla libre mirando la mesa, comen 25-55 s llevándose la mano a la boca y se van. A veces se les cae una miga. Hay hasta 10 a la vez y 5 ya sentados al empezar. El mozo ahora patrulla entre las mesas y las vidrieras (antes caminaba por el borde de la calle).
- **Tránsito** (`world/transito.gd`, `world/auto.gd`): autos, taxis negros y amarillos y colectivos por la avenida del sur, de mano derecha (hacia el este por el carril sur). Dos sendas peatonales con semáforos (verde 13 s, amarillo 2,5 s, rojo 8 s): los autos frenan en rojo, en amarillo si les da para frenar, detrás del de adelante y ante la gente que cruza. A las palomas no las esperan: tocan bocina; las sueltas que están en el camino vuelan un poquito y vuelven, y si un auto te toca salís volando hacia un costado (sin perder palomas, con 1,2 s de invulnerabilidad).
- Para que la calle quede libre, los dos edificios que la tapaban en las puntas (detrás del Cabildo y junto a la Casa Rosada) se movieron al sur de la avenida, alineados con los cafés.
- Sólo la carrocería y la cabina de los autos proyectan sombra: con 16 autos y 4 cortes de sombra, cada pieza chica sumaba decenas de dibujos por cuadro.
- Pruebas nuevas: `tests/captura_arreglos.tscn` (capturas de cada arreglo y una prueba de que las palomas NPC no atraviesan paredes) y `tests/bench_fps.tscn` (FPS con cámara fija, sin vsync).

## Versión para teléfonos (Android, en el navegador)
- Es otra exportación web (preset **"Web Android"**, en `docs/android/`) con la feature `movil`. Todo lo táctil depende de `Ajustes.movil`, así la versión de PC no cambia en nada.
- **Joystick flotante** en la mitad izquierda: aparece donde apoyás el dedo. **Deslizar en la mitad derecha** mueve la cámara. Los botones van abajo a la derecha, en arco alrededor del pulgar: DESPEGAR/ALETEAR (el más grande; mantener), PICADA (mantener; se ve apagado en el piso), PICOTEAR y ARRULLAR. La pausa, arriba a la derecha.
- Los controles táctiles aprietan las mismas acciones del Input Map que el teclado, así la paloma no se entera de con qué la manejan. Picotear y arrullar pierden sus clicks de mouse en el teléfono, porque Godot convierte el primer dedo en click.
- **Volando, la cámara se acomoda sola detrás de la paloma** si no la estás moviendo con el dedo: inclinar el joystick a un costado es doblar.
- Arranca en calidad Baja con el 3D a 720p (los teléfonos tienen muchos píxeles). Guarda sus opciones en un archivo aparte (`opciones_movil.cfg`).
- En vertical aparece un cartel de "girá el teléfono", y al primer toque pide pantalla completa y bloquea la orientación horizontal (si el navegador lo permite).
