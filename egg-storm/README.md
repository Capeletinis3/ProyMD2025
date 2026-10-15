# Egg Storm

Juego de Roblox (MVP). El código está en Luau y se sincroniza con Roblox Studio usando **Rojo**.

## Estructura

```
egg-storm/
├── default.project.json      ← le dice a Rojo dónde va cada carpeta dentro de Studio
├── rokit.toml                ← versión de Rojo del proyecto (si usás Rokit)
└── src/
    ├── shared/   → ReplicatedStorage.Shared           (lo ven servidor y cliente)
    │   ├── Config.luau                                 todos los números de balance
    │   ├── Creatures.luau                              catálogo de mascotas
    │   ├── Upgrades.luau                               niveles, precios y textos de las mejoras
    │   ├── Format.luau                                 números lindos (12,345)
    │   └── Remotes.luau                                RemoteEvents (servidor ↔ cliente)
    ├── server/   → ServerScriptService.Server          (solo servidor)
    │   ├── Main.server.luau                            arranca los servicios
    │   └── Services/
    │       ├── MapBuilder.luau                         arma el mapa placeholder
    │       ├── BaseService.luau                        asigna/libera bases
    │       ├── PlayerDataService.luau                  datos de cada jugador (plata, mascotas...)
    │       ├── EggService.luau                         lluvia de huevos, agarrar y llevar
    │       ├── IncubatorService.luau                   incubadoras y apertura de huevos
    │       ├── CreatureService.luau                    mascotas en la base y plata por segundo
    │       ├── CreatureModels.luau                     modelos placeholder de las mascotas
    │       ├── UpgradeService.luau                     compra y aplica las mejoras
    │       ├── BaseFloors.luau                         segundo piso de la base ("Base Floor")
    │       └── StormService.luau                       ciclo de tormenta y ola
    └── client/   → StarterPlayer.StarterPlayerScripts.Client (cada jugador)
        ├── Main.client.luau
        ├── Notifier.luau                               avisos en pantalla
        ├── IncubatorPrompts.luau                       muestra "Incubate" solo cuando corresponde
        ├── UpgradePanel.luau                           ventana de mejoras
        └── StormClient.luau                            cartel de fase, "WAVE INCOMING", lluvia y la ola
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
- **Guardado (fase 7)**: Game Settings → Security → activar **Enable Studio Access to API Services**.
