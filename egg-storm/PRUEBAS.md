# Prueba guiada con 2 jugadores

Hacela en Studio antes de publicar. Tarda unos 15 minutos.

## Preparación
1. El lugar tiene que estar **publicado** (File → Publish to Roblox).
2. **Game Settings → Security → Enable Studio Access to API Services**: activado.
3. Para que la prueba sea rápida, en `Config` cambiá temporalmente:
   - `Config.Economy.StartingCoins = 20000`
   - `Config.Storm.RainDuration = 30` y `CalmDuration = 10`
   - `Config.Upgrades.MinIncubationTime = 1` y los `BaseIncubationTime` de cada rareza a `5`
4. Pestaña **Test → Clients and Servers → 2 jugadores → Start**. Se abren 3 ventanas: el servidor y 2 jugadores.

> ⚠️ Cuando termines, **volvé todos esos números a como estaban**.

## Checklist

### Bases
- [ ] Jugador 1 aparece en la base 1 (roja) y Jugador 2 en la base 2 (naranja), cada uno con su nombre en el cartel.
- [ ] Cada uno ve el botón "Open" solo en el panel de su propia base.

### Huevos
- [ ] Caen huevos con el círculo de aviso; los Legendary/Secret tienen columna de luz.
- [ ] Los dos pueden agarrar huevos distintos. El huevo se ve arriba de la cabeza (también desde la otra ventana).
- [ ] Si los dos van al mismo huevo, solo se lo lleva uno.
- [ ] Con un huevo encima, no se puede agarrar otro ("You can only carry 1 egg at a time!").
- [ ] Abajo a la izquierda aparece "Carrying: ... Egg".

### Incubadoras y apertura
- [ ] El botón "Incubate" aparece solo en tu base y solo si llevás un huevo.
- [ ] Jugador 2 no puede usar la incubadora de Jugador 1.
- [ ] Cuenta regresiva arriba de la incubadora.
- [ ] Al terminar: el huevo tiembla, brilla, explota y aparece el cartel "YOU GOT ...".
- [ ] La mascota aparece en un pad y la plata sube cada segundo (abajo a la izquierda y en la lista de jugadores).

### Mejoras
- [ ] La ventana de mejoras se lee bien, sin textos encimados.
- [ ] Comprar cada mejora: Incubation Speed (el tiempo de un huevo incubando baja), Extra Incubator (aparece la incubadora 2), Walk Speed (corrés más rápido), Base Floor (aparece el segundo piso).
- [ ] Botón rojo si no te alcanza, "MAX" cuando está al máximo.

### Tormenta y ola
- [ ] Cielo oscuro y lluvia durante "EGG RAIN".
- [ ] Cartel "WAVE INCOMING" con cuenta regresiva y pitido.
- [ ] Jugador 1 en el lobby, Jugador 2 en la arena con un huevo: solo muere Jugador 2, pierde el huevo y reaparece en su base.
- [ ] Después de la ola no quedan huevos en el piso y vuelve el sol.

### Guardado
- [ ] Con Jugador 1: juntá plata, comprá algo, dejá un huevo incubando. Cerrá todo (Stop) y volvé a empezar: tiene que estar todo igual, incluida la cuenta regresiva del huevo.
- [ ] En la ventana del servidor (Output) no aparecen errores en rojo.

### Celular
- [ ] **Test → Device** → elegí un teléfono: la ventana de mejoras, la plata y los avisos entran en la pantalla.
