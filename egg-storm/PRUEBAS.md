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
   - Renacimiento barato: `Config.Rebirth.BaseCost = 1000`
   - Comerciante más seguido: `Config.Merchant.RestockInterval = 60`
   - Lluvia de huevos más seguido: `Config.EggRain.Interval = 60`
   - Ruleta: `Config.Spin.FreeInterval = 60` (un giro gratis por minuto)
   - Para probar el VIP sin comprarlo: poné tu UserId en `Config.Vip.TestUserIds = { tuUserId }` (en Studio los jugadores de prueba tienen UserIds negativos: -1 y -2)
4. Pestaña **Test → Clients and Servers → 2 jugadores → Start**. Se abren 3 ventanas: el servidor y 2 jugadores.

> ⚠️ Cuando termines, **volvé todos esos números a como estaban** (ver PUBLICAR.md).

## Checklist

### Aldea de la selva (lobby)
- [ ] Aparecés al lado del Altar del volcán (pileta de lava con un huevo dorado gigante que gira) con 8 antorchas alrededor, en una plaza de piedra.
- [ ] La plaza está rodeada por un **foso de agua turquesa** con nenúfares, flores de loto y peces koi. Se puede cruzar mojándose los pies o por los **4 puentes de madera** arqueados con faroles.
- [ ] Los 4 puestos están **en diagonal**, del otro lado del foso: **UPGRADES** (azul), **MYSTERY MERCHANT** (violeta), **RANKINGS** (naranja), **TRADING** (verde).
- [ ] Arriba a la izquierda: **laguna con cascada** (con niebla), piedras para cruzar, 3 flamencos, juncos, nenúfares, 2 bancos y mariposas.
- [ ] Abajo a la izquierda: **árbol gigante** con una casita de paja en una plataforma. Se sube por la **escalera de soga** (cartel "CLIMB ↑"). Columpio, lianas, faroles colgando, hongos que brillan y luciérnagas.
- [ ] Arriba a la derecha: **fogón tiki** con fuego y chispas, 3 filas de troncos para sentarse y un **escenario** con máscara tiki gigante y tambores.
- [ ] Abajo a la derecha: **jardín de los huevos** con los 6 huevos gigantes de las rarezas en nidos con cartel (Legendary, Mythic y Secret brillan y giran), flores gigantes y un arco de flores.
- [ ] Una **pasarela de madera** sale de los puentes norte y sur, pasa por delante de los hábitats y llega a la entrada de cada uno. Selva entre los hábitats (árboles, helechos, monsteras, luciérnagas).
- [ ] Camino de piedras del puente este al **Portal tiki** (dos tótems con cara y el cartel "TO THE CANYON ⚠").
- [ ] Al fondo, al final del cañón, se ve el **volcán** grande (curvo, con barrancos), humo enorme con brasas y 3 ríos de lava.

### Isla v2 (salí del lobby caminando)
- [ ] El terreno aparece en unos segundos al apretar Play, empezando cerca del lobby (en modo edición no se ve, es normal).
- [ ] Colinas con selva a los dos lados del cañón y acantilados de roca pegados a sus paredes. No se puede entrar al cañón desde arriba ni por el lado del volcán (pared invisible).
- [ ] Punta noroeste: **faro** a rayas con luz que gira y un **barco hundido** en el agua.
- [ ] Caleta norte: **laguna** con **cascada**. Península sur: **muelle** con 2 botes.
- [ ] Playas con palmeras y conchas, arrecifes claros y rocas en el agua.
- [ ] Volcán: se puede subir; arriba el cráter tiene un lago de lava que brilla.
- [ ] Estando en las colinas, la ola no te agarra (solo dentro del cañón).
- [ ] UPGRADES: "Open" abre la ventana de mejoras. MYSTERY MERCHANT y TRADING abren sus ventanas (ver más abajo).
- [ ] RANKINGS: tablero de plata arriba, de huevos abiertos a un costado y el tablero **EVENTS** al otro (próxima ola, súper tsunami y evento; cambia solo).

### Hábitats (bases)
- [ ] Cada jugador tiene su hábitat (Jugador 1 el 1, Jugador 2 el 2) con su nombre en el cartel del portal de la entrada.
- [ ] Muro natural de rocas redondo: bajo adelante y alto atrás, con musgo y selva arriba. La entrada es un portal de pilares de piedra con máscaras tiki, antorchas, techito de paja y guirnalda de flores.
- [ ] Atrás: acantilado con **cascada de 2 saltos** (con niebla) entre dos árboles grandes, que cae a un pozo. Un arroyo con un **tronco de puente** baja hasta un **lago** adelante a la izquierda (arena, nenúfares, juncos).
- [ ] Atrás a la izquierda, una terraza de piedra con el **refugio de paja** (cama de heno y farol). 2 grutas (una con hongos que brillan y otra con cristales), 2 comederos, palmeras, monsteras, helechos y un tronco caído.
- [ ] A la derecha de la entrada, los **3 nidos** en un altar de piedra: el 1 dice "EMPTY"; el 2 y el 3, "LOCKED" hasta comprar "Extra Nest".
- [ ] Cartel al lado de la entrada: "🐾 0/20 · +$0/s" (se actualiza con tus criaturas y lo que ganan).
- [ ] Hay lugar para **20 criaturas desde el principio** (no hace falta mejorar ni renacer).

### Cañón y huevos
- [ ] 6 zonas con su piso y su cartel en la pared: BEACH (Common), JUNGLE (Rare), ROCKS (Epic), BASALT (Legendary), COOLED LAVA (Mythic), OBSIDIAN (Secret).
- [ ] Paredes de roca con selva arriba, decoración de cada zona (conchas, arbustos y lianas, rocas, columnas de basalto, grietas de lava con humo, cristales violetas).
- [ ] Hay huevos en el piso que giran y flotan; cada zona da su rareza (a veces la siguiente). Al agarrar uno, en un rato aparece otro.
- [ ] Algunos son Silver, Golden, Emerald, Diamond o Rainbow ("Golden Rare Egg"). Los Legendary o mejores y los Emerald o mejores tienen columna de luz.
- [ ] El huevo se lleva en la mano. Con uno encima no se puede agarrar otro (salvo con la mejora **Carry Eggs** o VIP). Abajo al medio, el casillero 1 muestra el huevo que llevás.
- [ ] Con la mejora **Luck** (o la poción Luck x2), a veces al agarrar un huevo sale "🍀 Lucky! It became a ...".

### Nidos y criaturas
- [ ] Con un huevo, en tu nido aparece "Place Egg": el huevo queda en el nido con luz y chispitas y una cuenta regresiva (fondo azul). Abajo al medio del HUD, el cartelito "Nest 1 00:45" cuenta igual.
- [ ] Jugador 2 no puede usar los nidos de Jugador 1.
- [ ] Al terminar: el huevo se agrieta, dice "READY!" (fondo dorado, y en el HUD "Nest 1 READY!") y aparece "Open". No se abre solo.
- [ ] Al abrirlo: tiembla, explota con confeti y aparece "YOU GOT ...". La criatura aparece en tu hábitat y **pasea**: camina dando saltitos, se queda mirando y a veces se echa a dormir. La plata sube cada segundo.
- [ ] Se puede vender una criatura aunque se haya alejado un poco de su lugar (mantener E sobre ella).
- [ ] Con las **20** llenas te avisa "Your habitat is full!": vendiendo una, se puede seguir.

### Olas y cuevas
- [ ] Arriba al medio dice "NEXT WAVE", abajo "Run to a cave!" (o "The village is safe" si estás en el lobby) y el tiempo. Al llegar a 0: "THE WAVE IS COMING!", cuenta regresiva, cuerno y la cámara tiembla (si estás en el cañón). El volcán echa más humo.
- [ ] La ola (pared de agua con espuma) sale del fondo y recorre el cañón hasta el portal. Nunca entra a la isla.
- [ ] Jugador 1 metido en una cueva (marco de madera con antorcha): no le pasa nada.
- [ ] Jugador 2 afuera con un huevo: pierde el huevo y aparece en la isla ("The wave got you!").
- [ ] A veces la ola es rápida (menos aviso). Con `SuperInterval` corto: "SUPER TSUNAMI", más alta, con aviso más largo y anuncio para todos.
- [ ] La cueva VIP (marco dorado) tiene un botón "Get VIP" y una pared invisible: sin VIP no se puede entrar (ver "VIP").

### Eventos
- [ ] Cartel grande al empezar y, abajo del cartelito de la ola, el nombre del evento con su tiempo:
  - **GOLDEN RAIN**: muchos más huevos Silver/Golden/Emerald y reaparecen más rápido.
  - **LUCKY STORM**: cada zona da más seguido la rareza siguiente.
  - **DOUBLE COINS**: la plata por segundo dice "(x2!)" y sube el doble.
  - **METEOR SHOWER**: cada 10 segundos cae un meteorito en llamas (círculo rojo) con un huevo Epic o mejor.

### Renacimiento
- [ ] El botón **Rebirth [0]** del HUD abre la ventana naranja con "REBIRTH LEVEL 0 → 1", "∞ UNLIMITED" y tres cuadros: YOU GET (bonus X1.00 → X1.25), YOU LOSE y YOU KEEP. Cuando te alcanza la plata, el botón dice "READY!".
- [ ] La barra de abajo muestra tu plata contra el precio ("Ready!" cuando alcanza) y el precio del siguiente.
- [ ] Sin plata suficiente el botón está apagado y no hace nada. Con plata: la plata vuelve a 0, Hatching y Speed vuelven a nivel 1 y la plata por segundo sube un 25%. El botón pasa a "Rebirth [1]".
- [ ] Las criaturas, los huevos de los nidos, Extra Nest, Luck y Carry Eggs se conservan.
- [ ] **No hay máximo**: cada uno cuesta x2.5 el anterior (100K, 250K, 625K...). Después de Stop + Play sigue todo igual.

### Mejoras
- [ ] El ícono **UPGRADE SHOP** de la derecha (o el "+" al lado de tu velocidad, o el puesto UPGRADES) abre la ventana de bambú con 5 cartas: **Speed, Carry Eggs, Hatching, Luck y Extra Nest**, cada una con su nivel, 10 bolitas, el valor de ahora → el siguiente y el precio.
- [ ] Los botones **x1 / x10 / MAX** cambian cuántos niveles comprás de una ("x3 · 1,550"). Se compran los que alcance la plata ("Speed upgraded x3!").
- [ ] Se puede comprar desde cualquier lado. Al llegar al máximo aparece el sello "MAX!".
- [ ] **Carry Eggs** te deja llevar 2 huevos (y se suma con el VIP: 3).

### Comerciante misterioso v2
- [ ] El ícono **MYSTERY MERCHANT** de la derecha (o "Open" en el puesto violeta) abre la ventana de noche con estrellas: el comerciante dice "Psst... I have eggs you won't find in the canyon.", "New offers in mm:ss" y el botón **Renew · precio**.
- [ ] 2 estantes con 6 ofertas: 3 huevos con nombre (Coral, Storm, Sun, Lava o Crystal Egg, a veces con variante), el **Mystery Egg** y 2 pociones (**Luck x2** y **Fast Nests**). Cada una dice "Left N".
- [ ] Comprar un huevo lo pone directo en un nido libre tuyo. El Mystery Egg avisa qué salió ("🎲 The Mystery Egg was a ...!").
- [ ] Con "Left 0" aparece el sello **SOLD OUT**. Sin nido libre o sin plata, avisa y no cobra.
- [ ] **Renew** cobra y trae ofertas nuevas con todo el stock. Cada jugador tiene sus propias ofertas.
- [ ] Las pociones muestran un cartelito arriba de tu plata ("🍀 Luck x2 09:58"). Fast Nests hace que la cuenta regresiva del nido baje el doble de rápido. El tiempo se guarda (si salís y volvés, sigue donde estaba).

### Lluvia de huevos
- [ ] Arriba a la derecha dice "Egg rain in mm:ss" (y abajo a la derecha el ícono 🥚 con el tiempo).
- [ ] Al llegar a 0: aviso "🥚 EGG RAIN!" para todos y durante 45 segundos caen huevos del cielo por todo el cañón (con un circulito dorado donde van a caer). Muchos vienen con variante.
- [ ] Los que nadie agarra desaparecen después de un rato.

### Intercambio (con los 2 jugadores)
- [ ] Jugador 1 toca **Trade** en el HUD (o "Open" en el puesto verde): muestra la lista de jugadores. Toca a Jugador 2: "Trade request sent".
- [ ] A Jugador 2 le aparece arriba "Player1 wants to trade with you!" (esté donde esté). "Decline" avisa a Jugador 1; "Accept" abre la ventana a los dos.
- [ ] Cada uno toca hasta 4 mascotas suyas (se ponen verdes) y ve la oferta del otro con la plata por segundo de cada una.
- [ ] Mientras una mascota está ofrecida no se puede vender ("That creature is in a trade!").
- [ ] Los dos aprietan **Ready**: "Trading in 3...". Si alguien cambia algo en esos 3 segundos, se corta y hay que apretar Ready de nuevo.
- [ ] Al terminar: "Trade complete!", las mascotas se mudan de hábitat (con su variante) y la plata por segundo se actualiza. Después de Stop + Play sigue igual.
- [ ] Si a alguien no le alcanza el lugar del hábitat, avisa y no cambia nada. Si alguien aprieta Cancel o sale del juego, se cancela para los dos.

### VIP
- [ ] El botón **V.I.P** del HUD y el "Get VIP" de la cueva abren la ventana VIP: ticket dorado con el precio, botón verde "BUY 199" y las 6 ventajas.
- [ ] "BUY" dice "VIP isn't available yet" (si `GamePassId = 0`) o abre la compra del pase.
- [ ] Con VIP (por ejemplo con `TestUserIds`):
  - el botón V.I.P tiene un "✓", la ventana dice "✓ OWNED" y no aparece "Get VIP" en la cueva;
  - podés entrar a la cueva VIP caminando (un jugador sin VIP choca con la entrada) y protege de la ola;
  - tu plata por segundo es el doble y los nidos tardan 20% menos;
  - podés llevar **un huevo más** (uno en cada mano); se ve en los casilleros de abajo;
  - al entrar te llega un **huevo Rare dorado** a un nido libre (uno por día; la ventana dice cuánto falta para el próximo);
  - corona dorada con "VIP" arriba de tu cabeza y **[VIP]** dorado delante de tu nombre en el chat.
- [ ] "Gift it to a friend? Tap here": lista de jugadores sin VIP. Con `GiftProductId = 0` avisa que no está; con el producto creado abre la compra y al pagar el otro pasa a ser VIP (y lo sigue siendo cuando vuelve).

### HUD
- [ ] Arriba a la izquierda: la ruleta **SPIN** y 6 botones: **Shop** (con "NEW!"), **Trade**, **Index**, **V.I.P**, **Rebirth [n]** e **Invite** (con tu bonus "+0%"). Debajo, la barra **[T] Slow walk: OFF**.
- [ ] La tecla **T** (o tocar la barra) prende y apaga caminar lento ("ON"); al apagarlo volvés a tu velocidad.
- [ ] Abajo a la izquierda: tu velocidad con un "+", tu plata y "+$X/s". Arriba a la derecha: "Super tsunami in", "Egg rain in" y "Merchant in". Abajo al medio: los cartelitos de los 3 nidos y los casilleros de huevos (los que no podés usar todavía tienen 🔒).
- [ ] **Index**: todas las criaturas por rareza; las que tuviste alguna vez con su color y nombre, las demás "???". Arriba dice "Discovered N/15". Se guarda.
- [ ] **Invite** abre la ventana de invitar de Roblox. Si Jugador 1 y Jugador 2 son amigos en Roblox, los dos ven "+10%" y ganan 10% más (hasta +50% con 5 amigos).

### Ruleta y Tienda
- [ ] **SPIN** abre la ruleta con 6 premios (Coins, Legendary Egg, Luck x2, Fast Nests, Epic Egg, Rare Egg). Con el giro gratis dice "🎁 FREE SPIN READY!" (y el botón SPIN del HUD, "FREE!").
- [ ] "SPIN!" la hace girar unos segundos y frena en el premio, que se entrega en el momento (los huevos van a un nido libre; si no hay, te da monedas).
- [ ] Después dice "Next free spin in 23:59:59". Sin giros, el botón está gris.
- [ ] "Buy 1 spin" dice que todavía no se puede (si `Config.Spin.ProductId = 0`) o abre la compra. Al pagar: "You got 1 spin" y "Extra spins: 1".
- [ ] **Shop** abre la Tienda: Lucky Spin, VIP Pass (abre la ventana VIP) y Gift VIP (abre la lista para regalar).

### Tutorial (con un jugador nuevo)
> Para ver el tutorial de nuevo con tu cuenta, cambiá `Config.Data.StoreName` a otro nombre (empezás de cero) y después volvelo como estaba.
- [ ] Cartel arriba con un círculo de color, "STEP 1/4" y 4 rayitas, el título, qué hacer, la distancia ("➜ 42m") y "Skip tutorial". Una flecha de luz te lleva al objetivo.
- [ ] 1 **GRAB AN EGG!** (ir por el portal tiki y agarrar un huevo) → 2 **RUN BACK!** (volver a la isla con el huevo; muestra cuánto falta para la ola) → 3 **HATCH IT!** (ponerlo en un nido) → 4 **GET RICH!** (comprar tu primera mejora; muestra el precio).
- [ ] Al terminar cada paso aparece **"STEP COMPLETE! +100 coins"** y te dan las monedas.
- [ ] Si viene la ola y estás en el cañón: "HIDE IN A CAVE!" y la flecha apunta a la cueva más cercana. Si perdés el huevo: "GRAB ANOTHER EGG!".
- [ ] Al final: "Tutorial complete!". "Skip tutorial" lo termina en cualquier momento (sin monedas).

### Guardado
- [ ] Con Jugador 1: juntá plata, comprá algo, dejá un huevo incubando y otro listo. Cerrá todo (Stop) y volvé a empezar: tiene que estar todo igual (la cuenta regresiva sigue donde estaba y el listo sigue "READY!").
- [ ] En la ventana del servidor (Output) no aparecen errores en rojo.

### Ganancia mientras no estás
- [ ] Con al menos una mascota, salí del juego, esperá más de 1 minuto y volvé a entrar: aparece "Welcome back!" con la plata ganada.

### Celular
- [ ] **Test → Device** → elegí un teléfono: la ventana de mejoras, los carteles de ola y de evento, la plata y los avisos entran en la pantalla.
- [ ] También entran las ventanas de Rebirth, Comerciante, Intercambio, Índice, Ruleta y Tienda, el cartel de invitación y los botones del HUD (todo se achica junto). Los relojes de abajo a la derecha se esconden en el celular (ahí va el botón de saltar).
