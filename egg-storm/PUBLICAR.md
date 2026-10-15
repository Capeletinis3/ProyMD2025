# Qué falta para publicar Egg Storm

Ordenado por importancia. Lo marcado con 🔴 conviene hacerlo **sí o sí** antes de abrir el juego al público.

## 1. Configuración en Roblox
- 🔴 **Max Players = 8**: Game Settings → Places → (tu lugar) → Server Size. El código no lo puede cambiar.
- 🔴 **Cuestionario de madurez / contenido** (Creator Dashboard → tu experiencia → Audience / Maturity & Compliance). Sin eso Roblox no la muestra.
- 🔴 **Ícono (512×512) y miniaturas (1920×1080)**: son lo que hace que la gente entre. Grabá el momento de apertura de un Legendary para las miniaturas o un video.
- 🔴 **Nombre, descripción y género** en inglés.
- Dispositivos permitidos: PC, celular, tablet y consola (probar con **Test → Device**).

## 2. Volver los números de prueba a la normalidad
- 🔴 Revisá `Config` antes de publicar: `StartingCoins = 0`, `RainDuration = 90`, `CalmDuration = 20`, `ChancePerStorm = 0.4`, `MinIncubationTime = 5` y los `BaseIncubationTime` originales (30/60/90/120/180).

## 3. Cosas de juego que todavía no están
- ✅ ~~¿Qué pasa cuando se llenan los 14 lugares de mascotas?~~ **Hecho:** ahora se pueden vender mascotas (mantener E sobre una mascota tuya). El precio está en `Config.Economy.SellValueSeconds`.
- ✅ ~~Tutorial corto~~ **Hecho:** cartel con el paso a seguir + flecha de luz, se guarda el progreso y se puede saltear.
- ✅ ~~Escalera al segundo piso~~ **Hecho:** escalera de mano por el costado de la estantería de la base.
- ✅ ~~Ganancia mientras no estás~~ **Hecho:** 50% de lo normal, tope de 8 horas (`Config.Economy.Offline...`).
- ✅ ~~Tabla de récords~~ **Hecho:** dos tableros en el lobby (plata ganada en total y huevos abiertos), top 10 de todos los servidores.
- ✅ **Mapa playa + mar** (como el video de referencia): bases estantería, pasillo turquesa con corales y algas, cartel colgante de eventos, puesto de mejoras en el lobby y burbujas de vidrio.
- ✅ **Pulido:** variantes de huevo (Silver x2, Golden x3, Emerald x5, Diamond x10, Rainbow x25), cualquier rareza en cualquier parte del pasillo (lejos un poco mejor), 4 eventos de tormenta, pasillo de 1500 y mapa más colorido. Todo ajustable en `Config.Variants`, `Config.Events` y `Config.Rarities` (`FarBonus`).

## 4. Modelos y sonidos (reemplazar los placeholders)
- Modelos de mascotas (13), huevos, incubadora y panel de mejoras. Al reemplazarlos, el resto del código sigue igual (ver `CreatureModels.luau` y `MapBuilder.luau`).
- Sonidos: aviso de ola, ola, apertura de huevo, agarrar huevo, comprar mejora y música de fondo. Los IDs van en `Config.Storm` y `Config.Effects`.
- Textura de gota para la lluvia (`StormClient.luau`).

## 5. Seguridad y datos
- **Bloqueo de sesión del guardado**: si alguien sale y entra muy rápido a OTRO servidor, en un caso raro un guardado viejo podría pisar uno nuevo. Para un juego grande se recomienda la librería **ProfileStore** (gratis, de la comunidad), que resuelve esto.
- **Anti-trampas**: el servidor ya valida distancias, plata, dueño y spam. Lo que NO controla es la velocidad de caminata (en Roblox el cliente mueve su personaje). Un chequeo de "se movió demasiado rápido" en el servidor ayudaría.

## 6. Probar en serio
- Correr la prueba de `PRUEBAS.md` con 2 jugadores.
- Probar en un servidor real con amigos (8 jugadores) y en un celular de verdad.
- Ajustar el balance mirando cuánto tarda alguien en conseguir su primera mejora y su primer Legendary.

## 7. Lo que quedó para después (ya está preparado en el código)
- Robo de huevos entre jugadores y defensas: cada huevo incubando ya es un objeto del servidor con dueño, rareza y tiempo (`IncubatorService`).
- Gamepasses / Robux.
- Huevos de evento (Halloween, Navidad): se agregan como rarezas nuevas en `Config.Rarities` + mascotas en `Creatures.luau`, o como variantes nuevas en `Config.Variants`.
- Eventos nuevos de tormenta: se agregan en `Config.Events.List` y su efecto en `EventService.luau`.
- Trading.
