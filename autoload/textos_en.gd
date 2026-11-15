class_name TextosEN
extends RefCounted
## Traducción al inglés de todos los textos del juego. La clave es el texto en español tal como
## está escrito en el código o en la escena: Godot traduce solo los Label, Button, Label3D,
## tooltips y ítems de lista, y lo demás pasa por tr(). Idioma.instalar() arma la Translation
## y agrega sola la versión en MAYÚSCULAS de cada clave (muchos textos se muestran así).
## Para agregar un texto nuevo: escribirlo en español en el código y sumar acá su par.

const MAPA := {
	# Menú principal y pausa
	"CONTINUAR": "CONTINUE",
	"NUEVA PARTIDA": "NEW GAME",
	"CARGAR PARTIDA": "LOAD GAME",
	"OPCIONES": "OPTIONS",
	"SALIR": "QUIT",
	"PAUSA": "PAUSED",
	"REINICIAR": "RESTART",
	"SALIR AL MENÚ": "QUIT TO MENU",
	"VOLVER": "BACK",

	# Cargar partida
	"Cargar partida": "Load game",
	"Partida guardada": "Saved game",
	"BORRAR": "DELETE",
	"CARGAR": "LOAD",
	"¿SEGURO?": "ARE YOU SURE?",
	"TODAVÍA NO HAY NINGUNA PARTIDA GUARDADA.\nLA PARTIDA SE GUARDA SOLA MIENTRAS JUGÁS.":
		"THERE IS NO SAVED GAME YET.\nTHE GAME SAVES BY ITSELF AS YOU PLAY.",
	"PALOMA": "PIGEON",
	"PALOMAS": "PIGEONS",
	"%d %s  ·  %d DE COMIDA": "%d %s  ·  %d FOOD",
	"TIEMPO JUGADO %d:%02d\nGUARDADA EL %s A LAS %s": "TIME PLAYED %d:%02d\nSAVED ON %s AT %s",

	# Opciones
	"Opciones": "Options",
	"Música": "Music",
	"Voz": "Voice",
	"Efectos": "Effects",
	"SILENCIAR TODO": "MUTE ALL",
	"Pantalla": "Display",
	"Brillo": "Brightness",
	"Calidad": "Quality",
	"Baja": "Low",
	"Media": "Medium",
	"Alta": "High",
	"Resolución": "Resolution",
	"NATIVA": "NATIVE",
	"Límite de FPS": "FPS limit",
	"Sin límite": "Unlimited",
	"Con un número fijo se desactiva el VSync": "A fixed number turns VSync off",
	"Pantalla completa": "Fullscreen",
	"Controles": "Controls",
	"Sensibilidad": "Sensitivity",
	"Invertir eje Y": "Invert Y axis",
	"Tamaño de la ventana": "Window size",
	"En pantalla completa (o en el navegador) el 3D se dibuja a esta resolución":
		"In fullscreen (or in the browser) the 3D is drawn at this resolution",

	# HUD
	"COMIDA": "FOOD",
	"EN EL PICO": "IN BEAK",
	"MISIÓN": "MISSION",
	"TE ESCOLTARON AL NIDO": "YOU WERE ESCORTED TO THE NEST",
	"EL HALCÓN TE SOLTÓ": "THE HAWK DROPPED YOU",
	"DE VUELTA AL NIDO": "BACK TO THE NEST",
	"NIDO · comida %d": "NEST · food %d",

	# Tipos de comida
	"miga": "crumb",
	"medialuna": "croissant",
	"papa": "fries",
	"factura": "pastry",
	"choripan": "choripán",

	# Controles táctiles
	"VOLAR": "FLY",
	"PICOTEAR": "PECK",
	"PICADA": "DIVE",
	"ARRULLAR": "COO",
	"ALETEAR": "FLAP",
	"DESPEGAR": "TAKE OFF",

	# Cinemáticas
	"Tocá la pantalla para saltear": "Tap the screen to skip",
	"Espacio o click: saltear": "Space or click: skip",
	"¡Hola, paloma flaca! ¿Ves a Doña Rosa?": "Hi, skinny pigeon! See Doña Rosa?",
	"Todas las mañanas les tira migas a las palomas del Cabildo":
		"Every morning she tosses crumbs to the pigeons at the Cabildo",
	"Las migas te dan energía para volar... ¡y comida para armar tu bandada!":
		"Crumbs give you energy to fly... and food to build your flock!",
	"¡Andá a comer vos también!": "Go eat too!",
	"Este es tu nido: la Pirámide de Mayo": "This is your nest: the May Pyramid",
	"La comida grande (medialunas, papas, facturas) llevala al nido":
		"Carry the big food (croissants, fries, pastries) to the nest",
	"OBJETIVO: juntá 30 palomas y tomá el balcón de la Casa Rosada":
		"GOAL: gather 30 pigeons and take the Casa Rosada balcony",
	"Con 30 palomas los granaderos se distraen... ¡y la plaza es nuestra!":
		"With 30 pigeons the grenadiers get distracted... and the square is ours!",

	# Tutorial (teclado y mouse)
	"Caminá hasta las migas de Doña Rosa\nWASD para moverte, el mouse para mirar":
		"Walk to Doña Rosa's crumbs\nWASD to move, mouse to look around",
	"Picoteá las migas con CLICK IZQUIERDO\nTe dan energía para volar y comida":
		"Peck the crumbs with LEFT CLICK\nThey give you energy to fly, and food",
	"CLICK DERECHO cerca de las palomas para arrullar\nCada una que se suma a tu bandada cuesta 1 de comida":
		"RIGHT CLICK near the pigeons to coo\nEach one that joins your flock costs 1 food",
	"ESPACIO para despegar\nMantenelo apretado para subir": "SPACE to take off\nHold it down to climb",
	"En el aire, SHIFT para tirarte en picada\n¡Soltalo y salís disparada para arriba!":
		"In the air, SHIFT to dive\nLet go and you shoot upward!",
	"OBJETIVO: juntá 30 palomas\ny tomá el balcón de la Casa Rosada":
		"GOAL: gather 30 pigeons\nand take the Casa Rosada balcony",
	"¡Bien! Andá a la Catedral (al norte)\na reclutar más palomas":
		"Nice! Head to the Cathedral (north)\nto recruit more pigeons",
	# Tutorial (teléfono)
	"Caminá hasta las migas de Doña Rosa\nJoystick a la izquierda, deslizá a la derecha para mirar":
		"Walk to Doña Rosa's crumbs\nJoystick on the left, swipe on the right to look around",
	"Tocá PICOTEAR cerca de las migas\nTe dan energía para volar y comida":
		"Tap PECK near the crumbs\nThey give you energy to fly, and food",
	"Tocá ARRULLAR cerca de las palomas\nCada una que se suma a tu bandada cuesta 1 de comida":
		"Tap COO near the pigeons\nEach one that joins your flock costs 1 food",
	"Tocá DESPEGAR para volar\nMantené ALETEAR apretado para subir":
		"Tap TAKE OFF to fly\nHold FLAP to climb",
	"En el aire, mantené PICADA para tirarte en picada\n¡Soltala y salís disparada para arriba!":
		"In the air, hold DIVE to dive\nLet go and you shoot upward!",

	# Objetivos y avisos
	"¡La plaza es nuestra!": "The square is ours!",
	"Llevá la %s al nido, en la Pirámide de Mayo": "Take the %s to the nest, at the May Pyramid",
	"Comé las migas de Doña Rosa, en el Cabildo": "Eat Doña Rosa's crumbs, at the Cabildo",
	"Conseguí comida: migas, medialunas de los cafés o facturas del subte":
		"Find food: crumbs, croissants from the cafés or pastries from the subway",
	"Reclutá palomas en la Catedral": "Recruit pigeons at the Cathedral",
	"Levantá el choripán de la avenida y juntá más palomas":
		"Lift the choripán on the avenue and gather more pigeons",
	"Cuidado con el halcón y seguí juntando palomas": "Watch out for the hawk and keep gathering pigeons",
	"Tomá el balcón de la Casa Rosada con tu bandada": "Take the Casa Rosada balcony with your flock",
	"¡5 palomas! Ya pueden levantar el choripán de la avenida":
		"5 pigeons! You can now lift the choripán on the avenue",
	"¡15 palomas! Los turistas les tienen miedo... y apareció un halcón":
		"15 pigeons! The tourists are scared of you... and a hawk showed up",
	"¡30 palomas! Los granaderos están distraídos. ¡Al balcón!":
		"30 pigeons! The grenadiers are distracted. To the balcony!",

	# Brújula: puntos cardinales (N, E y S son iguales) y nombres de los destinos
	"O": "W",
	"SO": "SW",
	"NO": "NW",
	"Nido": "Nest",
	"Catedral": "Cathedral",
	"Subte": "Subway",
	"Balcón": "Balcony",

	# Victoria y créditos
	"TIEMPO": "TIME",
	"¡LA PLAZA ES NUESTRA!": "THE SQUARE IS OURS!",
	"LA BANDADA": "THE FLOCK",
	"VOLVER AL MENÚ": "BACK TO MENU",
	"y la paloma flaca que empezó todo": "and the skinny pigeon who started it all",
	"La paloma flaca": "The skinny pigeon",
	"Hecho con Godot para una game jam\nNinguna medialuna fue desperdiciada":
		"Made with Godot for a game jam\nNot a single croissant was wasted",

	# Carteles de la ciudad (mapa V2). Los nombres de calles y negocios no se traducen.
	"DIARIOS Y REVISTAS": "NEWSPAPERS",
	"Plaza de juegos": "Playground",
	"Parque de perros": "Dog park",
	"PROHIBIDO\nPALOMAS": "NO\nPIGEONS",
	"A LAS PALOMAS\nDE LA PLAZA": "TO THE PIGEONS\nOF THE SQUARE",
}
