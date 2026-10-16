# Cómo poner las imágenes del diseño en el juego

El HUD, el comerciante y la ventana de mejoras ya están preparados para usar los íconos dibujados del diseño
(la bolsa de la tienda, la corona VIP, la ruleta, el huevo, la poción...). Están en la carpeta **`imagenes/`**
(21 PNG de 256 × 256 con fondo transparente; `_todas.png` es una hoja para verlos juntos, esa no se sube).

Roblox **no deja usar imágenes sueltas** desde el código: cada una hay que subirla a Roblox una vez, y Roblox le da un número
(Asset ID). Ese número se pega en `Config.Images`. Mientras un número esté vacío, en su lugar se ve un emoji,
así que el juego anda igual aunque no subas ninguna.

## Paso a paso (unos 5 minutos)

1. Abrí el lugar en Studio. Tiene que estar **publicado** (File → Publish to Roblox), si no Studio no deja subir imágenes.
2. **View → Asset Manager**. Arriba, el botón **Bulk Import** (la flechita para arriba).
3. Elegí **todos los PNG** de la carpeta `imagenes` (menos `_todas.png`) y aceptá. Aparecen en la carpeta **Images** del Asset Manager.
   Roblox los revisa (moderación): puede tardar unos minutos en que se vean.
4. En cada imagen: **clic derecho → Copy Asset ID**. Te copia algo como `rbxassetid://1234567890`.
5. Abrí `src/shared/Config.luau` (en Studio: ReplicatedStorage → Shared → Config) y buscá `Config.Images`.
   Pegá cada número en su nombre, entre comillas:

   ```lua
   Shop = "rbxassetid://1234567890",
   Vip = "rbxassetid://1234567891",
   ```

   (También vale pegar solo el número: `Shop = "1234567890"`.)
6. Play: donde pusiste un número se ve la imagen; donde no, sigue el emoji.

> Si usás Rojo, hacé el cambio en `src/shared/Config.luau` del proyecto (si lo cambiás solo en Studio, Rojo lo pisa la próxima vez que sincronices).

## Qué es cada imagen

| Archivo | Nombre en `Config.Images` | Dónde se ve |
|---|---|---|
| Spin.png | `Spin` | botón SPIN (reemplaza a la ruleta dibujada) |
| Shop.png, Trade.png, Index.png, Vip.png, Rebirth.png, Invite.png | igual que el archivo | los 6 botones del HUD |
| UpgradeShop.png, Merchant.png | `UpgradeShop`, `Merchant` | los íconos grandes de la derecha |
| Speed.png, Coin.png | `Speed`, `Coin` | abajo a la izquierda (velocidad y plata) |
| Wave.png, EggRain.png, SuperTsunami.png | igual que el archivo | relojes de abajo a la derecha |
| Egg.png, Potion.png, MysteryEgg.png | igual que el archivo | ofertas del comerciante (el huevo y la poción son blancos: el juego los pinta del color de cada oferta) |
| UpgradeSpeed.png, UpgradeCarry.png, UpgradeHatching.png, UpgradeLuck.png | igual que el archivo | círculos de la ventana de mejoras (Extra Nest queda con emoji: no tiene dibujo en el diseño) |

## Cambiar una imagen

Hacé tu PNG (cuadrado, con fondo transparente queda mejor), subilo igual y reemplazá el número en `Config.Images`.
