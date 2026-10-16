# Prueba guiada con 2 jugadores

Hacela en Studio antes de publicar. Tarda unos 15-20 minutos.

## Preparación
1. El lugar tiene que estar **publicado** (File → Publish to Roblox).
2. **Game Settings → Security → Enable Studio Access to API Services**: activado.
3. Para que la prueba sea rápida, en `Config` cambiá temporalmente:
   - `Config.Economy.StartingCoins = 20000`
   - `Config.Upgrades.MinIncubationTime = 1` y los `BaseIncubationTime` de cada rareza a `10`
   - Olas más seguido: `Config.Waves.MinInterval = 20` y `MaxInterval = 25`; para ver el súper tsunami: `SuperInterval = 90`
   - Eventos más seguido: `Config.Events.Interval = 30` y `Chance = 1`
4. Pestaña **Test → Clients and Servers → 2 jugadores → Start**. Se abren 3 ventanas: el servidor y 2 jugadores.

> ⚠️ Cuando termines, **volvé todos esos números a como estaban** (ver PUBLICAR.md).

## Checklist

### Isla (lobby)
- [ ] Aparecés al lado del Altar del volcán (pileta de lava con un huevo dorado gigante que gira) con 8 antorchas alrededor.
- [ ] Piso de arena, terrazas de pasto arriba y abajo con las 8 bases, palmeras, flores y conchas en la orilla. El mar alrededor.
- [ ] Camino de piedras del altar al **Portal tiki** (dos tótems con cara y el cartel "TO THE CANYON ⚠").
- [ ] Al fondo, detrás del cañón, se ve el **volcán** con humo y ríos de lava.
- [ ] 4 puestos con toldo a rayas mirando al altar: **UPGRADES** (azul), **MYSTERY MERCHANT** (violeta), **RANKINGS** (naranja), **TRADING** (verde).
- [ ] UPGRADES: "Open" abre la ventana de mejoras y se puede comprar. MYSTERY MERCHANT y TRADING dicen "coming soon".
- [ ] RANKINGS: tablero de plata arriba, de huevos abiertos a un costado y el tablero **EVENTS** al otro (próxima ola, súper tsunami y evento; cambia solo).

### Bases
- [ ] Cada jugador tiene su base (Jugador 1 la 1, Jugador 2 la 2) con su nombre en el cartel, arriba.
- [ ] Torre de bambú de 3 pisos con techo de paja, máscaras tiki y 2 antorchas. Pisos 2 y 3 con barrera celeste y candado.
- [ ] 5 estantes amarillos en el piso 1; los de arriba violetas (bloqueados). Escalera de mano al costado (no deja pasar a los pisos bloqueados).
- [ ] 3 nidos-incubadora ADELANTE de la torre: el 1 dice "EMPTY"; el 2 y el 3, "LOCKED" hasta comprar "Extra Incubator".

### Cañón y huevos
- [ ] 6 zonas con su piso y su cartel en la pared: BEACH (Common), JUNGLE (Rare), ROCKS (Epic), BASALT (Legendary), COOLED LAVA (Mythic), OBSIDIAN (Secret).
- [ ] Paredes de roca con selva arriba, decoración de cada zona (conchas, arbustos y lianas, rocas, columnas de basalto, grietas de lava con humo, cristales violetas).
- [ ] Hay huevos en el piso que giran y flotan; cada zona da su rareza (a veces la siguiente). Al agarrar uno, en un rato aparece otro.
- [ ] Algunos son Silver, Golden, Emerald, Diamond o Rainbow ("Golden Rare Egg"). Los Legendary o mejores y los Emerald o mejores tienen columna de luz.
- [ ] El huevo se lleva en la mano. Con uno encima no se puede agarrar otro. Abajo a la izquierda: "Carrying: ... Egg".

### Incubadoras y estantes
- [ ] Con un huevo, en tu nido aparece "Place Egg": el huevo queda en el nido con luz y chispitas y una cuenta regresiva (fondo azul).
- [ ] Jugador 2 no puede usar los nidos de Jugador 1.
- [ ] Al terminar: el huevo se agrieta, dice "READY!" (fondo dorado) y aparece "Open". No se abre solo.
- [ ] Al abrirlo: tiembla, explota con confeti y aparece "YOU GOT ...". La mascota va al primer estante libre y la plata sube cada segundo.
- [ ] Con los 5 estantes llenos te avisa que vendas una (mantener E sobre una mascota tuya). Vendiendo una, se puede seguir.

### Olas y cuevas
- [ ] Arriba dice "NEXT WAVE 0:xx". Al llegar a 0: "THE WAVE IS COMING!", cuenta regresiva, cuerno y la cámara tiembla (si estás en el cañón). El volcán echa más humo.
- [ ] La ola (pared de agua con espuma) sale del fondo y recorre el cañón hasta el portal. Nunca entra a la isla.
- [ ] Jugador 1 metido en una cueva (marco de madera con antorcha): no le pasa nada.
- [ ] Jugador 2 afuera con un huevo: pierde el huevo y aparece en la isla ("The wave got you!").
- [ ] A veces la ola es rápida (menos aviso). Con `SuperInterval` corto: "SUPER TSUNAMI", más alta, con aviso más largo y anuncio para todos.
- [ ] La cueva VIP (marco dorado) está cerrada por ahora.

### Eventos
- [ ] Cartel grande al empezar y, abajo del cartelito de la ola, el nombre del evento con su tiempo:
  - **GOLDEN RAIN**: muchos más huevos Silver/Golden/Emerald y reaparecen más rápido.
  - **LUCKY STORM**: cada zona da más seguido la rareza siguiente.
  - **DOUBLE COINS**: la plata por segundo dice "(x2!)" y sube el doble.
  - **METEOR SHOWER**: cada 10 segundos cae un meteorito en llamas (círculo rojo) con un huevo Epic o mejor.

### Tutorial (con un jugador nuevo)
> Para ver el tutorial de nuevo con tu cuenta, cambiá `Config.Data.StoreName` a otro nombre (empezás de cero) y después volvelo como estaba.
- [ ] "Go through the tiki portal and grab an egg in the canyon!" con una flecha de luz.
- [ ] Con el huevo: "Bring the egg to an incubator..." y la flecha apunta a tu nido. Si viene la ola y estás en el cañón: "Hide in a cave!" y la flecha apunta a la cueva más cercana.
- [ ] Cuando está listo: "Your egg is READY! Open it!". Después: "Visit the Upgrades shop" con la flecha al puesto. Al abrirlo: "Tutorial complete!".
- [ ] "Skip" lo termina en cualquier momento.

### Guardado
- [ ] Con Jugador 1: juntá plata, comprá algo, dejá un huevo incubando y otro listo. Cerrá todo (Stop) y volvé a empezar: tiene que estar todo igual (la cuenta regresiva sigue donde estaba y el listo sigue "READY!").
- [ ] En la ventana del servidor (Output) no aparecen errores en rojo.

### Ganancia mientras no estás
- [ ] Con al menos una mascota, salí del juego, esperá más de 1 minuto y volvé a entrar: aparece "Welcome back!" con la plata ganada.

### Celular
- [ ] **Test → Device** → elegí un teléfono: la ventana de mejoras, los carteles de ola y de evento, la plata y los avisos entran en la pantalla.
