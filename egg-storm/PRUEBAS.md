# Prueba guiada con 2 jugadores

Hacela en Studio antes de publicar. Tarda unos 15 minutos.

## Preparación
1. El lugar tiene que estar **publicado** (File → Publish to Roblox).
2. **Game Settings → Security → Enable Studio Access to API Services**: activado.
3. Para que la prueba sea rápida, en `Config` cambiá temporalmente:
   - `Config.Economy.StartingCoins = 20000`
   - `Config.Storm.RainDuration = 30` y `CalmDuration = 10`
   - Para ver los eventos seguido: `Config.Events.ChancePerStorm = 1` (todas las tormentas tienen evento)
   - `Config.Upgrades.MinIncubationTime = 1` y los `BaseIncubationTime` de cada rareza a `5`
4. Pestaña **Test → Clients and Servers → 2 jugadores → Start**. Se abren 3 ventanas: el servidor y 2 jugadores.

> ⚠️ Cuando termines, **volvé todos esos números a como estaban**.

## Checklist

### Tutorial (con un jugador nuevo)
> Para ver el tutorial de nuevo con tu cuenta, cambiá `Config.Data.StoreName` a otro nombre (empezás de cero) y después volvelo como estaba.
- [ ] Arriba aparece "Grab an egg in the sand!" y una flecha de luz desde tu personaje al huevo más cercano.
- [ ] Al agarrarlo: "Bring the egg to your incubator!" y la flecha apunta a tu incubadora.
- [ ] Al incubar: "Your egg is incubating!...". Si viene la ola y estás en la arena: "WAVE INCOMING! Run back..." con la flecha a tu base.
- [ ] Cuando sale la mascota: "Open the Upgrades panel" con la flecha al panel. Al abrirlo: "Tutorial complete!".
- [ ] "Skip" lo termina en cualquier momento.

### Bases
- [ ] Todas las bases son iguales: piso gris con una estantería de metal azul y techo violeta a rayas. Jugador 1 aparece en la base 1 y Jugador 2 en la base 2, cada uno con su nombre en el cartel (arriba del techo).
- [ ] Cada uno ve el botón "Open" solo en el panel de su propia base.

### Huevos
- [ ] Caen huevos con el círculo de aviso en todo el pasillo (no hay zonas): cerca de la entrada también pueden caer raros, pero lejos salen un poco más seguido.
- [ ] Algunos huevos son Silver, Golden, Emerald, Diamond o Rainbow: se ven de ese color/material, brillan, y al acercarte dice por ejemplo "Golden Rare Egg".
- [ ] Los Legendary, Secret y los Emerald o mejores tienen columna de luz.
- [ ] Los dos pueden agarrar huevos distintos. El huevo se ve arriba de la cabeza (también desde la otra ventana).
- [ ] Si los dos van al mismo huevo, solo se lo lleva uno.
- [ ] Con un huevo encima, no se puede agarrar otro ("You can only carry 1 egg at a time!").
- [ ] Abajo a la izquierda aparece "Carrying: ... Egg" (con la variante, por ejemplo "Carrying: Golden Rare Egg").

### Incubadoras y apertura
- [ ] El botón "Incubate" aparece solo en tu base y solo si llevás un huevo.
- [ ] Jugador 2 no puede usar la incubadora de Jugador 1.
- [ ] Cuenta regresiva arriba de la incubadora.
- [ ] Al terminar: el huevo tiembla, brilla, explota y aparece el cartel "YOU GOT ...". Con variante dice por ejemplo "GOLDEN EPIC" y "(x3)".
- [ ] Una mascota con variante se ve de ese color/material, el cartel dice "Golden ..." y gana x2/x3/x5/x10/x25.
- [ ] La mascota aparece en un pad y la plata sube cada segundo (abajo a la izquierda y en la lista de jugadores).

### Vender mascotas
- [ ] Sobre una mascota tuya aparece "Sell" con el precio; sobre las de otro jugador no aparece.
- [ ] Mantener E vende la mascota: desaparece, sube la plata y baja la plata por segundo.
- [ ] Con todos los lugares llenos, al querer incubar te avisa que vendas una; después de vender, se puede incubar.

### Lobby
- [ ] Piso de arena con baldosas, dos burbujas de vidrio con algas en las esquinas.
- [ ] Cartel colgante a la izquierda de la entrada del pasillo: dice cuánto falta para la tormenta / la ola y si hay evento (cambia solo).
- [ ] Puesto "UPGRADES" a la derecha: apretando "Open" se abre la ventana de mejoras y se puede comprar desde ahí.

### Mejoras
- [ ] La ventana de mejoras se lee bien, sin textos encimados.
- [ ] Comprar cada mejora: Incubation Speed (el tiempo de un huevo incubando baja), Extra Incubator (aparece la incubadora 2), Walk Speed (corrés más rápido), Base Floor (aparece el segundo piso).
- [ ] Botón rojo si no te alcanza, "MAX" cuando está al máximo.
- [ ] Con el segundo piso: aparece el estante del medio (violeta a rayas). Trepar por la escalera de mano del costado, pasar por el hueco de la baranda y vender una mascota de arriba.

### Tormenta y ola
- [ ] Con sol los colores se ven bien vivos. Cielo oscuro y lluvia durante "EGG RAIN".
- [ ] El pasillo es mucho más largo (1500) y parece fondo del mar: piso turquesa, paredes azules con corales y algas arriba, algas, corales, cofres y burbujas a los costados, carteles 250m, 500m...
- [ ] Caminando normal no llegás al fondo y volvés antes de la ola; con las mejoras de Walk Speed sí.
- [ ] Cartel "WAVE INCOMING" con cuenta regresiva y pitido.
- [ ] Jugador 1 en el lobby, Jugador 2 en la arena con un huevo: solo muere Jugador 2, pierde el huevo y reaparece en su base.
- [ ] Después de la ola no quedan huevos en el piso y vuelve el sol.

### Eventos de tormenta
- [ ] A veces la tormenta arranca con un cartel grande de evento y arriba se ve su nombre en vez de "EGG RAIN":
  - **GOLDEN RAIN**: lluvia dorada y muchos más huevos Silver/Golden/Emerald...
  - **LUCKY STORM**: más Epic, Legendary y Secret.
  - **DOUBLE COINS**: abajo a la izquierda la plata por segundo dice "(x2!)" y la plata sube el doble.
  - **METEOR SHOWER**: cada 10 segundos cae un meteorito en llamas (círculo rojo) con un huevo Epic o mejor.
- [ ] Cuando vuelve la calma, el evento termina.

### Guardado
- [ ] Con Jugador 1: juntá plata, comprá algo, dejá un huevo incubando. Cerrá todo (Stop) y volvé a empezar: tiene que estar todo igual, incluida la cuenta regresiva del huevo y las variantes (Golden, etc.).
- [ ] En la ventana del servidor (Output) no aparecen errores en rojo.

### Ganancia mientras no estás
- [ ] Con al menos una mascota, salí del juego, esperá más de 1 minuto y volvé a entrar: aparece "Welcome back!" con la plata ganada y ya está sumada.
- [ ] Si volvés antes de 1 minuto, no aparece el cartel.

### Tabla de récords
- [ ] En el lobby, sobre la pared a cada lado de la entrada del pasillo, hay dos tableros: "TOP EARNERS" y "MOST EGGS HATCHED".
- [ ] A los ~10 segundos de arrancar se llenan (en Studio sin acceso a la API dicen "This server only").
- [ ] Gastar plata en mejoras no te baja en "TOP EARNERS".

### Celular
- [ ] **Test → Device** → elegí un teléfono: la ventana de mejoras, la plata y los avisos entran en la pantalla.
