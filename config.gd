class_name Config
extends RefCounted
## Valores ajustables globales del juego.
## Los valores de movimiento de la paloma están como @export en player/paloma.gd
## (así se pueden tocar desde el inspector); acá van los umbrales y la economía.

# --- Bandada ---
const BANDADA_MAX := 60            ## Tope de palomas que te siguen
const UMBRAL_CHORIPAN := 5         ## Palomas necesarias para levantar el choripán
const UMBRAL_TURISTAS := 15        ## Palomas para asustar grupos de turistas
const UMBRAL_HALCON := 15          ## Al llegar a esta bandada aparece el halcón
const UMBRAL_BALCON := 30          ## Palomas para distraer granaderos y tomar el balcón
const RADIO_BALCON := 3.4          ## Metros (en el plano) alrededor del balcón que cuentan como "estar sobre él"

# --- Stamina ---
const STAMINA_MAX := 100.0
const STAMINA_DESPEGUE := 8.0      ## Costo de despegar
const STAMINA_ALETEO := 14.0       ## Costo por segundo manteniendo Espacio en el aire
const STAMINA_PLANEO := 1.5        ## Costo por segundo sólo por estar en el aire
const STAMINA_RECARGA_SUELO := 10.0     ## Recarga por segundo apenas aterrizás (las migas siguen siendo lo más rápido)
const STAMINA_RECARGA_SUELO_MAX := 40.0 ## ...y a la que llega después de STAMINA_RAMPA_SUELO segundos en el piso
const STAMINA_RAMPA_SUELO := 2.5        ## Cuánto tarda en llegar a la recarga máxima (de 0 a lleno: unos 3,5 s)
const STAMINA_MIGA := 18.0         ## Recarga al comer una miga


## Recarga por segundo en el suelo después de "segundos" en el piso: cuanto más tiempo, más rápido
## (el juego es de explorar y divertirse: no hay que castigar a quien se queda sin aire).
static func recarga_suelo(segundos: float) -> float:
	return lerpf(STAMINA_RECARGA_SUELO, STAMINA_RECARGA_SUELO_MAX, clampf(segundos / STAMINA_RAMPA_SUELO, 0.0, 1.0))

# --- Comida (unidades de "comida acumulada") ---
const COMIDA_MIGA := 1
const COMIDA_PAPA := 3
const COMIDA_MEDIALUNA := 4
const COMIDA_CHORIPAN := 12
const COSTO_RECLUTAR := 1          ## Comida por paloma reclutada
const RADIO_ARRULLO := 7.0         ## Radio en metros del arrullo
const RADIO_NIDO := 6.0            ## Radio del nido para entregar comida

# --- Penalizaciones ---
const PERDIDA_NENE := 0.25         ## Fracción de la bandada que dispersa el nene
const PERDIDA_HALCON := 3          ## Palomas que perdés si te atrapa el halcón
const PERDIDA_GRANADERO := 2       ## Palomas que perdés si te atrapa un granadero

# --- Tiempo ---
const DURACION_PARTIDA := 840.0    ## Segundos de "día" (14 minutos) para el ciclo de luz
