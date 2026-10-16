# Qué falta para publicar Egg Storm

Ordenado por importancia. Lo marcado con 🔴 conviene hacerlo **sí o sí** antes de abrir el juego al público.

## 1. Configuración en Roblox
- 🔴 **Max Players = 8**: Game Settings → Places → (tu lugar) → Server Size. El código no lo puede cambiar.
- 🔴 **Cuestionario de madurez / contenido** (Creator Dashboard → tu experiencia → Audience / Maturity & Compliance). Sin eso Roblox no la muestra.
- 🔴 **Ícono (512×512) y miniaturas (1920×1080)**: son lo que hace que la gente entre. Grabá el momento de apertura de un Legendary para las miniaturas o un video.
- 🔴 **Nombre, descripción y género** en inglés.
- Dispositivos permitidos: PC, celular, tablet y consola (probar con **Test → Device**).
- 🔴 **Pase VIP**: Creator Dashboard → tu experiencia → **Monetization → Passes → Create a Pass** (nombre "VIP", ícono, y ponerlo **On Sale** con su precio en Robux). Copiá el número del pase (Pass ID) y pegalo en `Config.Vip.GamePassId`. Con 0, el juego funciona pero nadie puede comprar el VIP.
- **Regalar VIP**: Monetization → **Developer Products → Create** (nombre "VIP Gift", mismo precio que el pase). Pegá su número en `Config.Vip.GiftProductId`. Con 0, el botón de regalo avisa que no está.
- **Giros de la ruleta**: Monetization → **Developer Products → Create** (nombre "Lucky Spin", 25 Robux o lo que quieras). Pegá su número en `Config.Spin.ProductId` y el precio en `Config.Spin.PriceRobux` (solo para mostrarlo). Con 0, el botón "Buy 1 spin" avisa que todavía no se puede.
- **Invitar amigos**: no hace falta configurar nada (usa la ventana de invitar de Roblox). El bonus está en `Config.Friends`.
- Si cambiás el precio del pase, cambiá también `Config.Vip.PriceRobux` (es solo lo que muestra la ventana).
- Dejá `Config.Vip.TestUserIds = {}` vacío (salvo que quieras regalarle el VIP a alguien).

## 2. Volver los números de prueba a la normalidad
- 🔴 Revisá `Config` antes de publicar: `StartingCoins = 0`, `MinIncubationTime = 5`, los `BaseIncubationTime` originales (30/60/180/480/1200/2700), `Waves.MinInterval = 60`, `MaxInterval = 90`, `SuperInterval = 1800`, `Events.Interval = 240` y `Chance = 0.5`, `Rebirth.BaseCost = 100000`, `Merchant.RestockInterval = 600`, `EggRain.Interval = 900` y `Spin.FreeInterval = 86400`.

## 3. Cosas de juego que todavía no están
- ✅ ~~¿Qué pasa cuando se llenan los 14 lugares de mascotas?~~ **Hecho:** ahora se pueden vender mascotas (mantener E sobre una mascota tuya). El precio está en `Config.Economy.SellValueSeconds`.
- ✅ ~~Tutorial corto~~ **Hecho:** 4 pasos (Grab an egg, Run back, Hatch it, Get rich) con cartel, flecha de luz y +100 monedas por paso (`Config.Tutorial`). Se guarda el progreso y se puede saltear.
- ✅ ~~Escalera al segundo piso~~ **Hecho:** escalera de mano al costado de la torre.
- ✅ ~~Ganancia mientras no estás~~ **Hecho:** 50% de lo normal, tope de 8 horas (`Config.Economy.Offline...`).
- ✅ ~~Tabla de récords~~ **Hecho:** dos tableros en el lobby (plata ganada en total y huevos abiertos), top 10 de todos los servidores.
- ✅ **Mapa "Isla tropical + volcán"** (MAPA_SPEC.md): cañón de 6 zonas (cada una con su rareza), 12 cuevas-refugio y olas del volcán (normal, rápida y súper tsunami).
- ✅ **Aldea de la selva** (el lobby): plaza del altar con foso y 4 puentes, puestos en diagonal, laguna con cascada, árbol gigante con casita, fogón tiki con escenario, jardín de los 6 huevos gigantes y pasarela de madera hasta cada hábitat (`Config.Village`, `VillageBuilder.luau`).
- ✅ **Hábitats de selva** (las bases): muro de rocas, cascada, lago, refugio, grutas y 3 nidos. **20 criaturas por jugador desde el principio** (sin pisos ni mejoras de espacio) y las criaturas pasean por el hábitat (`Config.Habitat`, `HabitatBuilder.luau`).
- ✅ **Renacimiento** (botón Rebirth): plata a 0 y velocidades a nivel 1, a cambio de +25% de plata para siempre. Ilimitado: cada uno cuesta x2.5 el anterior (`Config.Rebirth`).
- ✅ **Mejoras nuevas**: Speed, Carry Eggs (+1 huevo, se suma con el VIP), Hatching, Luck (más chance de que el huevo suba de rareza) y Extra Nest, con x1/x10/MAX y desde cualquier lado (`Config.Upgrades`).
- ✅ **Comerciante v2**: 6 ofertas por jugador (3 huevos con nombre, huevo misterioso, pociones Luck x2 y Fast Nests) con stock, SOLD OUT, tanda nueva cada 10 minutos y "Renew" pagando (`Config.Merchant`, `Config.Potions`).
- ✅ **Lluvia de huevos**: cada 15 minutos, 45 segundos de huevos cayendo por todo el cañón, con más variantes (`Config.EggRain`).
- ✅ **HUD nuevo**: ruleta, Shop, Trade, Index, V.I.P, Rebirth, Invite, caminar lento [T], relojes, nidos y casilleros de huevos.
- ✅ **Ruleta**: 1 giro gratis por día y giros extra con Robux (falta crear el producto, ver punto 1) (`Config.Spin`).
- ✅ **Índice** de criaturas descubiertas y **bonus por amigos** (+10% por amigo en el servidor, hasta +50%).
- ✅ **Intercambio entre jugadores**: hasta 4 mascotas cada uno, los dos "Ready" + 3 segundos, el servidor revisa todo y guarda enseguida (`Config.Trade`).
- ✅ **Pase VIP** (199 Robux): x2 de plata, cueva VIP, incubación 20% más rápida, 1 huevo más para llevar, huevo Rare dorado gratis cada día, corona y [VIP] en el chat. Se puede regalar. Falta crear el pase y el producto de regalo (ver punto 1) (`Config.Vip`).
- ✅ **Pulido:** variantes de huevo (Silver x2, Golden x3, Emerald x5, Diamond x10, Rainbow x25), cualquier rareza en cualquier parte del pasillo (lejos un poco mejor), 4 eventos de tormenta, pasillo de 1500 y mapa más colorido. Todo ajustable en `Config.Variants`, `Config.Events` y `Config.Rarities` (`FarBonus`).

## 4. Modelos y sonidos (reemplazar los placeholders)
- Modelos de mascotas (15), huevos, incubadora y panel de mejoras. Al reemplazarlos, el resto del código sigue igual (ver `CreatureModels.luau` y `MapBuilder.luau`).
- Sonidos: ver "Próximas fases" (los IDs van en `Config.Waves` y `Config.Effects`).

## 5. Seguridad y datos
- **Bloqueo de sesión del guardado**: si alguien sale y entra muy rápido a OTRO servidor, en un caso raro un guardado viejo podría pisar uno nuevo. Para un juego grande se recomienda la librería **ProfileStore** (gratis, de la comunidad), que resuelve esto.
- **Anti-trampas**: el servidor ya valida distancias, plata, dueño y spam. Lo que NO controla es la velocidad de caminata (en Roblox el cliente mueve su personaje). Un chequeo de "se movió demasiado rápido" en el servidor ayudaría.

## 6. Probar en serio
- Correr la prueba de `PRUEBAS.md` con 2 jugadores.
- Probar en un servidor real con amigos (8 jugadores) y en un celular de verdad.
- Ajustar el balance mirando cuánto tarda alguien en conseguir su primera mejora y su primer Legendary.

## 7. Próximas ideas
- Historial de intercambios (para ayudar a jugadores que digan que les robaron) y confirmación extra si cambiás una mascota muy valiosa.
- Sonidos de la Creator Store: cuerno de caracol, rugido de la ola, retumbe del volcán, música tiki, olas, "pop" al abrir, la cascada de la laguna y el fogón (los IDs van en `Config.Waves` y `Config.Effects`).
- Recompensas por completar el Índice (por ejemplo, un huevo especial al descubrir todas las de una rareza).
- Eventos en el escenario del fogón tiki (el escenario ya está armado en la aldea).

## 8. Lo que quedó para después (ya está preparado en el código)
- Robo de huevos entre jugadores y defensas: cada huevo incubando ya es un objeto del servidor con dueño, rareza y tiempo (`IncubatorService`).
- Huevos de evento (Halloween, Navidad): se agregan como rarezas nuevas en `Config.Rarities` + mascotas en `Creatures.luau`, o como variantes nuevas en `Config.Variants`.
- Eventos nuevos de tormenta: se agregan en `Config.Events.List` y su efecto en `EventService.luau`.
