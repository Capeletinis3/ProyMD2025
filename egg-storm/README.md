# Egg Storm

Juego de Roblox (MVP). El código está en Luau y se sincroniza con Roblox Studio usando **Rojo**.

## Estructura

```
egg-storm/
├── default.project.json      ← le dice a Rojo dónde va cada carpeta dentro de Studio (y pone la luz en "Future")
├── rokit.toml                ← versión de Rojo del proyecto (si usás Rokit)
├── MAPA_SPEC.md              ← cómo es el mapa (medidas, colores, zonas): el código lo sigue
├── PRUEBAS.md                ← prueba guiada con 2 jugadores
├── PUBLICAR.md               ← lo que falta para publicar
├── dev-tests/                ← pruebas automáticas (opcional, ver su README)
└── src/
    ├── shared/   → ReplicatedStorage.Shared           (lo ven servidor y cliente)
    │   ├── Config.luau                                 todos los números: mapa, zonas, cuevas, rarezas, olas, eventos...
    │   ├── Creatures.luau                              catálogo de mascotas
    │   ├── Upgrades.luau                               niveles, precios y textos de las mejoras
    │   ├── Format.luau                                 números lindos (12,345)
    │   └── Remotes.luau                                RemoteEvents (servidor ↔ cliente)
    ├── server/   → ServerScriptService.Server          (solo servidor)
    │   ├── Main.server.luau                            arranca los servicios
    │   └── Services/
    │       ├── MapBuilder.luau                         arma el lobby, el cañón, las cuevas, las bases, el faro, el muelle...
│       ├── IslandBuilder.luau                      la isla grande con Terrain (colinas, playas, arrecifes, volcán)
    │       ├── BaseService.luau                        asigna/libera bases
    │       ├── BaseFloors.luau                         abre y cierra los pisos de la torre (candados)
    │       ├── PlayerDataService.luau                  datos de cada jugador y guardado (DataStore)
    │       ├── EggService.luau                         huevos por zona (rareza + variante), meteoritos, agarrar y llevar
    │       ├── IncubatorService.luau                   nidos-incubadora: poner huevo, READY!, abrir
    │       ├── CreatureService.luau                    mascotas en los estantes, plata por segundo y venta
    │       ├── CreatureModels.luau                     modelos placeholder de las mascotas
    │       ├── UpgradeService.luau                     compra y aplica las mejoras (Tienda del lobby)
    │       ├── WaveService.luau                        olas del volcán y cuevas-refugio
    │       ├── EventService.luau                       eventos especiales (Golden Rain, Lucky Storm...)
    │       ├── StallService.luau                       avisos de puestos del lobby sin sistema (hoy ninguno)
│       ├── RebirthService.luau                     renacimiento (abre pisos de la torre, +25% de plata)
│       ├── MerchantService.luau                    Comerciante misterioso (ofertas de huevos cada 10 min)
│       ├── TradeService.luau                       intercambio de mascotas entre jugadores
│       ├── VipService.luau                         pase VIP: ventajas, cueva VIP, huevo diario, corona y regalos
    │       ├── TutorialService.luau                    pasos del tutorial para jugadores nuevos
    │       └── LeaderboardService.luau                 tableros de récords (top 10 de todos los servidores)
    └── client/   → StarterPlayer.StarterPlayerScripts.Client (cada jugador)
        ├── Main.client.luau
        ├── UIKit.luau                                  estilo común de la interfaz (colores, letra, ajuste a pantalla)
        ├── Hud.luau                                    plata, plata por segundo y huevo que llevás
        ├── Notifier.luau                               avisos en pantalla
        ├── HatchReveal.luau                            animación de apertura y cartel "You got..."
        ├── Tutorial.luau                               cartel del tutorial y flecha que guía
        ├── WelcomeBack.luau                            cartel "Welcome back!" con lo que ganaste mientras no estabas
        ├── IncubatorPrompts.luau                       muestra "Place Egg" / "Open" solo cuando corresponde
        ├── SellPrompts.luau                            el botón "Sell" de cada mascota solo lo ve su dueño
        ├── UpgradePanel.luau                           ventana de mejoras
        ├── SideMenu.luau                               botones del costado izquierdo (Rebirth, VIP)
        ├── RebirthPanel.luau                           ventana de renacimiento
        ├── MerchantPanel.luau                          ventana del Comerciante
        ├── TradePanel.luau                             lista de jugadores, invitación y ventana de intercambio
        ├── VipClient.luau                              botón VIP, [VIP] en el chat y esconde "Get VIP" si ya lo tenés
        ├── VipPanel.luau                               ventana VIP (ticket dorado, ventajas, regalar)
        ├── WaveClient.luau                             próxima ola, "THE WAVE IS COMING!", la ola y los eventos
        ├── EventBoard.luau                             escribe el tablero de eventos del puesto de Rankings
        └── EggAnimator.luau                            hace girar y flotar los huevos del piso
```

Convención de nombres de Rojo:
- `X.server.luau` → `Script` (corre en el servidor)
- `X.client.luau` → `LocalScript` (corre en el jugador)
- `X.luau` → `ModuleScript` (código que otros scripts usan con `require`)

## Instalar Rojo (una sola vez)

**Opción A: VS Code (la más fácil)**
1. Instalá [Visual Studio Code](https://code.visualstudio.com/).
2. En VS Code, pestaña Extensions, buscá **"Rojo - Roblox Studio Sync"** (de evaera) e instalala.
3. Abrí la carpeta `egg-storm` en VS Code (File → Open Folder).
4. Abajo a la izquierda aparece un botón **Rojo**. Hacé clic → te ofrece instalar Rojo y el plugin de Studio. Aceptá las dos cosas.

**Opción B: línea de comandos (Rokit)**
1. Instalá [Rokit](https://github.com/rojo-rbx/rokit) siguiendo su README.
2. En una terminal, dentro de `egg-storm`: `rokit install` (baja Rojo 7.4.4).
3. `rojo plugin install` (instala el plugin en Studio).

## Sincronizar con Studio (cada vez que trabajes)

1. En Studio: File → New → **Baseplate**. Guardalo como `EggStorm.rbxl` donde quieras.
2. Iniciá el servidor de Rojo:
   - VS Code: botón **Rojo** → elegí `default.project.json` → *Start*.
   - Terminal: `rojo serve` dentro de `egg-storm`.
3. En Studio: pestaña **Plugins → Rojo → Connect**.
4. Listo: cada vez que guardes un archivo `.luau`, aparece actualizado en Studio.

> Siempre editá el código en los archivos (VS Code), no en Studio: Rojo pisa lo que cambies dentro de Studio.

## Configuración del lugar (Game Settings)

Hay que publicar el lugar una vez (File → Publish to Roblox) para poder cambiar estas opciones:
- **Máximo 8 jugadores**: Home → Game Settings → Places → (tu lugar) → Max Players = 8.
- **Guardado**: Game Settings → Security → activar **Enable Studio Access to API Services**.
  Sin esto, en Studio se puede jugar igual pero **no se guarda nada** (aparece un aviso amarillo en Output).
  El lugar tiene que estar publicado en Roblox para que el DataStore funcione.
