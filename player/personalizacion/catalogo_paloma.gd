class_name CatalogoPaloma
extends RefCounted
## Qué se puede personalizar de la paloma de la jugadora: las zonas de color, la paleta y los
## accesorios por slot. Sólo datos (los textos van en español y se traducen con tr()).
## El perfil guarda índices: color -1 = el original de la textura, accesorio 0 = ninguno.

## Zonas recoloreables. "zona" es el índice de la máscara (modelos/paloma/paloma_zonas.png).
const ZONAS := [
	{"clave": "cuerpo", "nombre": "Cuerpo", "zona": 1},
	{"clave": "alas", "nombre": "Alas", "zona": 2},
	{"clave": "cabeza", "nombre": "Cabeza y cuello", "zona": 3},
	{"clave": "cola", "nombre": "Cola", "zona": 4},
	{"clave": "pico", "nombre": "Pico", "zona": 5},
	{"clave": "patas", "nombre": "Patas", "zona": 6},
]

## Colores medios a propósito: los extremos (blanco puro, negro) aplanan el sombreado de las plumas.
const PALETA := [
	{"nombre": "Blanco", "color": Color("ece7da")},
	{"nombre": "Gris", "color": Color("9a9aa6")},
	{"nombre": "Grafito", "color": Color("55555f")},
	{"nombre": "Marrón", "color": Color("7a5238")},
	{"nombre": "Canela", "color": Color("c98a52")},
	{"nombre": "Amarillo", "color": Color("f0d04a")},
	{"nombre": "Coral", "color": Color("e8665a")},
	{"nombre": "Rosa", "color": Color("e68aa8")},
	{"nombre": "Violeta", "color": Color("9a72d0")},
	{"nombre": "Azul", "color": Color("4a6fd0")},
	{"nombre": "Celeste", "color": Color("78bde8")},
	{"nombre": "Verde", "color": Color("6fbf73")},
]

## Colores del modo pintura: la paleta de arriba más negro y blanco puro (acá no hay sombreado que aplanar).
const PALETA_PINTURA := [
	{"nombre": "Blanco puro", "color": Color("ffffff")},
	{"nombre": "Negro", "color": Color("1b1b22")},
	{"nombre": "Blanco", "color": Color("ece7da")},
	{"nombre": "Gris", "color": Color("9a9aa6")},
	{"nombre": "Grafito", "color": Color("55555f")},
	{"nombre": "Marrón", "color": Color("7a5238")},
	{"nombre": "Canela", "color": Color("c98a52")},
	{"nombre": "Amarillo", "color": Color("f0d04a")},
	{"nombre": "Coral", "color": Color("e8665a")},
	{"nombre": "Rosa", "color": Color("e68aa8")},
	{"nombre": "Violeta", "color": Color("9a72d0")},
	{"nombre": "Azul", "color": Color("4a6fd0")},
	{"nombre": "Celeste", "color": Color("78bde8")},
	{"nombre": "Verde", "color": Color("6fbf73")},
]

## Slots de accesorios. "hueso" es donde se ancla. "opciones" no incluye "Ninguno" (índice 0).
const SLOTS := [
	{"clave": "cabeza", "nombre": "Cabeza", "hueso": "head", "opciones": ["Gorra", "Moño", "Sombrero de copa", "Antenas"]},
	{"clave": "espalda", "nombre": "Espalda", "hueso": "body", "opciones": ["Mochilita", "Capa", "Jetpack"]},
	{"clave": "cola", "nombre": "Cola", "hueso": "tail", "opciones": ["Lazo", "Cinta", "Plumas de colores"]},
	{"clave": "pico", "nombre": "Pico", "hueso": "head", "opciones": ["Bigote", "Pipa", "Anteojos"]},
]


static func cantidad_opciones(slot: int) -> int:
	return (SLOTS[slot]["opciones"] as Array).size() + 1   # +1: "Ninguno"


## Nombre (en español, sin traducir) de la opción "i" del slot; 0 = "Ninguno".
static func nombre_opcion(slot: int, i: int) -> String:
	if i <= 0:
		return "Ninguno"
	return (SLOTS[slot]["opciones"] as Array)[i - 1]


static func color_paleta(i: int) -> Color:
	return PALETA[i]["color"]
