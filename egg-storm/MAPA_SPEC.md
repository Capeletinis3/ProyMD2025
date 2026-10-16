# Especificación del mapa — Juego de huevos (Roblox)

> **Para Claude Code:** este documento describe el mapa completo con medidas exactas en studs.
> Construí el mapa con un script generador (`MapBuilder`) que lea estos valores y cree las Parts,
> así se puede regenerar y ajustar. Si algo no está especificado, elegí lo más simple y
> coherente con el tema **isla tropical + volcán**. No inventes zonas ni edificios extra.

---

## 0. Resumen del juego (para entender el mapa)

1. El jugador aparece en el **lobby** (isla de arena) junto al **Altar del volcán**.
2. Cruza el **Portal tiki** y entra al **Cañón**, un pasillo largo con 6 zonas. Cuanto más lejos, más raros los huevos.
3. Agarra un huevo (lo lleva en la mano, solo 1 a la vez) y vuelve a su **base**.
4. Cada cierto tiempo el **volcán** (al fondo, en el mar) entra en erupción y manda una **ola** que barre el cañón hacia el lobby.
   Para salvarse hay que meterse en una **cueva-refugio**. Si la ola te toca fuera de una cueva: perdés el huevo que llevabas y volvés al lobby.
5. En la base, el jugador pone el huevo en una de sus **3 incubadoras** (están ADELANTE de la base). Tras un timer, nace una criatura.
6. La criatura va a un **estante** de la torre de la base y genera dinero por segundo.
7. Con el dinero compra mejoras en la **Tienda de mejoras** (incubación más rápida, etc.).

---

## 1. Sistema de coordenadas

- **Origen (0, 0, 0)** = centro del Altar del volcán, a nivel del piso.
- **Y** = arriba. La superficie del piso de todo el mapa está en **Y = 0** (las Parts del piso tienen 2 de alto y su centro en Y = -1).
- **+X** = hacia el cañón y el volcán (este). La ola viaja en dirección **-X**.
- **-Z** = norte (bases 1–4). **+Z** = sur (bases 5–8).
- Todas las medidas son en studs. Formato de tamaño: `X × Y × Z`.

```
        Z-  (norte)  Bases 1-4
   ┌───────────────────────┐
   │  terraza de pasto     │      ┌──────────────── CAÑÓN (1200 de largo) ──────────────────┐
   │                       │      │ Playa │ Selva │ Rocas │ Basalto │ Lava fría │ Obsidiana │ OLA ← VOLCÁN
   │   ALTAR (0,0,0)   ────┼─PORTAL                                                        │
   │                       │      └─────────────────────────────────────────────────────────┘
   │  terraza de pasto     │      X=150                                                X=1350      X≈1550
   └───────────────────────┘
        Z+  (sur)  Bases 5-8
   X=-150                X=150
```

---

## 2. Jerarquía en el Explorer

```
Workspace
└── Map
    ├── Lobby
    │   ├── Ground            (piso de arena + terrazas de pasto)
    │   ├── Altar
    │   ├── Stalls            (TiendaMejoras, Comerciante, Rankings, Intercambio)
    │   ├── Portal
    │   └── Decor             (Palms, Torches, Flowers, Stones)
    ├── Bases
    │   ├── Base1 … Base8     (cada una: Plot, Tower, Floors, Shelves, Incubators, Sign, SpawnPoint)
    ├── Canyon
    │   ├── Floor             (Zone1 … Zone6)
    │   ├── Walls
    │   ├── Caves             (Cave01 … Cave12, cada una con SafeZone)
    │   └── Decor
    ├── Ocean                 (Terrain de agua)
    ├── Volcano
    └── Wave                  (la Part de la ola, se mueve por script)
└── EggSpawns
    ├── Zone1 … Zone6         (Parts invisibles donde aparecen huevos)
ServerStorage
└── Props                     (modelos base: Palm, TikiTorch, Rock, Crystal, etc.)
ReplicatedStorage
└── Config                    (ModuleScripts: Rarities, Zones, Waves, Upgrades)
```

Todas las Parts del mapa: `Anchored = true`. Las decorativas que no se pisan: `CanCollide = false` si molestan al caminar (flores, conchas, grietas).

---

## 3. Paleta y materiales (usar SIEMPRE estos)

| Nombre | Hex | RGB | Material |
|---|---|---|---|
| Arena lobby | #F6DDB0 | 246, 221, 176 | Sand |
| Pasto terrazas | #6CC24A | 108, 194, 74 | Grass |
| Madera | #8B5A2B | 139, 90, 43 | WoodPlanks |
| Madera oscura (bordes) | #4A2C12 | 74, 44, 18 | Wood |
| Bambú | #C9A24A | 201, 162, 74 | Wood |
| Paja (techos) | #D9A441 | 217, 164, 65 | Fabric |
| Selva (paredes, copas) | #2F8A3C | 47, 138, 60 | LeafyGrass |
| Roca de pared | #7A6E62 | 122, 110, 98 | Rock |
| Piso Playa | #F2D49B | 242, 212, 155 | Sand |
| Piso Selva | #7CC46B | 124, 196, 107 | Grass |
| Piso Rocas | #ABA294 | 171, 162, 148 | Slate |
| Piso Basalto | #6E6863 | 110, 104, 99 | Basalt |
| Piso Lava fría | #4A3833 | 74, 56, 51 | CrackedLava |
| Piso Obsidiana | #261F33 | 38, 31, 51 | Slate |
| Lava | #FF6A1A | 255, 106, 26 | Neon |
| Cristal | #A35BFF | 163, 91, 255 | Glass |
| Piedra (altar, pedestales) | #8E857A | 142, 133, 122 | Slate |
| Luz de antorcha | #FF8A1F | 255, 138, 31 | (PointLight) |
| Agua | #1693B5 | 22, 147, 181 | Terrain Water |

Colores por rareza (huevos, luces de nido, partículas):

| Rareza | Hex | RGB |
|---|---|---|
| Común | #F4F4F4 | 244, 244, 244 |
| Raro | #60A5FA | 96, 165, 250 |
| Épico | #A78BFA | 167, 139, 250 |
| Legendario | #FCD34D | 252, 211, 77 |
| Mítico | #F87171 | 248, 113, 113 |
| Secreto | #111827 (con brillo blanco) | 17, 24, 39 |

---

## 4. Iluminación (servicio `Lighting`)

```
Lighting.Technology       = Future
Lighting.ClockTime        = 14.5
Lighting.Brightness       = 2.5
Lighting.Ambient          = Color3.fromRGB(90, 80, 70)
Lighting.OutdoorAmbient   = Color3.fromRGB(150, 140, 130)
Atmosphere:      Density 0.3, Haze 1, Glare 0.2, Color (199, 232, 240), Decay (106, 112, 125)
BloomEffect:     Intensity 0.6, Size 24, Threshold 1.5
ColorCorrection: Saturation 0.15, Contrast 0.05, TintColor (255, 245, 230)
SunRaysEffect:   Intensity 0.08, Spread 1
Terrain.WaterColor = (22, 147, 181), WaterTransparency = 0.6, WaterWaveSize = 0.15, WaterWaveSpeed = 8
```

---

## 5. Lobby (isla)

### 5.1 Piso
| Part | Tamaño | Posición (centro) | Material/color |
|---|---|---|---|
| LobbySand | 300 × 2 × 340 | (0, -1, 0) | Sand #F6DDB0 |
| TerraceNorth | 300 × 2.2 × 50 | (0, -0.9, -145) | Grass #6CC24A (queda 0.2 más alto que la arena) |
| TerraceSouth | 300 × 2.2 × 50 | (0, -0.9, 145) | Grass #6CC24A |
| Shore (borde) | anillo de 8 de ancho alrededor de la isla, Y = -1.5 | — | Sand #F2D49B (orilla mojada) |

Las esquinas de la isla se ven redondeadas: poné 4 cilindros de arena (diámetro 60, altura 2) en las esquinas para suavizar.

### 5.2 Altar del volcán (spawn) — centro (0, 0, 0)
| Part | Forma | Tamaño | Posición | Material/color |
|---|---|---|---|---|
| AltarRing | Cylinder (acostado en Y) | diámetro 34, alto 2 | (0, 1, 0) | Slate #8E857A |
| AltarRingEdge | Cylinder | diámetro 36, alto 1.5 | (0, 0.75, 0) | Slate #5E5751 |
| LavaPool | Cylinder | diámetro 18, alto 0.4 | (0, 2.1, 0) | Neon #FF6A1A |
| Pedestal | Block | 6 × 6 × 6 | (0, 5, 0) | Slate #8E857A |
| GoldenEgg | Sphere escalada a 5 × 7 × 5 (o MeshPart huevo) | — | (0, 11.5, 0) | Neon #FFD84D, gira 20°/s en Y y sube/baja ±0.5 |
| SpawnLocation | 12 × 1 × 12, invisible | (0, 2.5, 22) | Transparency 1 |

- **8 antorchas tiki** en círculo de radio 22 alrededor del altar, cada 45°. (Modelo en §9.2)
- PointLight dentro de LavaPool: color #FF6A1A, Range 16, Brightness 3.
- ParticleEmitter en LavaPool: chispas naranjas, Rate 8, Lifetime 1–2, Speed 4–8 hacia arriba.

### 5.3 Puestos (Stalls) — mismo modelo, cambia color de toldo y cartel
Modelo base 24 × 16 × 14 (§9.5). Frente mirando al altar.

| Puesto | Posición del centro | Frente mira hacia | Color toldo |
|---|---|---|---|
| TiendaMejoras | (-95, 0, -55) | +X/+Z (al altar) | #1E88E5 + blanco |
| Comerciante | (-95, 0, 55) | al altar | #8E3FD6 + blanco |
| Rankings | (95, 0, -55) | al altar | #E8590C + blanco |
| Intercambio | (95, 0, 55) | al altar | #0F9D8A + blanco |

- Rankings: tablero de madera 20 × 12 × 1 con SurfaceGui (top 10 de dinero) y al lado un **tablero de eventos** (SurfaceGui con timers: próxima ola, súper tsunami, lluvia de huevos).
- Cada puesto tiene un ProximityPrompt en el mostrador que abre su GUI.

### 5.4 Camino de piedras (altar → portal)
Piedras planas (Cylinder diámetro 5, alto 0.4, Slate #B8B0A3) a lo largo de Z = 0, desde X = 30 hasta X = 145, una cada 8 studs, alternando Z = -2 y Z = +2.

### 5.5 Portal tiki — entrada del cañón (X = 150)
| Part | Tamaño | Posición | Material/color |
|---|---|---|---|
| TotemNorth | 6 × 18 × 6 | (150, 9, -44) | Wood #A0522D, cara tallada con Decal (ojos #FFE27A) |
| TotemSouth | 6 × 18 × 6 | (150, 9, 44) | igual |
| Beam | 4 × 3 × 96 | (150, 19.5, 0) | WoodPlanks #8B5A2B |
| Sign | 2 × 4 × 24 | (149, 16, 0) | WoodPlanks, SurfaceGui: "AL CAÑÓN ⚠" |
| Antorchas | 2 | (146, 0, ±50) | modelo TikiTorch |

### 5.6 Decoración del lobby
- **Palmeras** (modelo §9.1) en: (-60, 0, -95), (60, 0, -95), (-60, 0, 95), (60, 0, 95), (-135, 0, -10), (-135, 0, 25), (135, 0, -95), (135, 0, 95). Altura variada 18–26, rotación Y aleatoria.
- **Flores de hibisco**: 20 repartidas en el borde de las terrazas (Z = ±120 aprox.), esferas 1.2 rosas #FF4F8B y amarillas #FFE27A, CanCollide false.
- **Conchas y estrellas de mar**: 15 en la orilla (Shore), CanCollide false.

---

## 6. Bases de jugadores (8)

> **Base v2:** cada base es una choza tiki de 3 pisos muy decorada (la arma `BaseBuilder.luau`, ~1000 piezas): pisos a Y = 2 / 14 / 26, estantes redondos al fondo, 2 escaleras exteriores, techo de paja de 3 capas, arco de entrada con el nombre del dueño, cerco, hamaca y cartel "BIGGER TOWER" (los pisos se abren renaciendo). Las medidas de abajo siguen valiendo para el terreno, la torre y los nidos.

### 6.1 Ubicación
Cada base ocupa un terreno (Plot) de **60 (X) × 44 (Z)**. El FRENTE de la base mira al centro del lobby.

| Base | Centro del Plot | Frente mira hacia |
|---|---|---|
| Base1 | (-117, 0, -148) | +Z |
| Base2 | (-39, 0, -148) | +Z |
| Base3 | (39, 0, -148) | +Z |
| Base4 | (117, 0, -148) | +Z |
| Base5 | (-117, 0, 148) | -Z |
| Base6 | (-39, 0, 148) | -Z |
| Base7 | (39, 0, 148) | -Z |
| Base8 | (117, 0, 148) | -Z |

Usá coordenadas **locales** dentro de cada base (el centro del Plot es (0,0,0) local; **+Z local = frente**) y rotá el modelo 180° para las bases del sur.

### 6.2 Partes de la base (coordenadas locales)
| Part | Tamaño | Posición local | Material/color |
|---|---|---|---|
| Plot (borde del terreno) | 60 × 0.3 × 44 | (0, 0.15, 0) | Grass #5DB33D (un poco más oscuro que la terraza) |
| Tower (volumen total) | 40 × 36 × 20 | centro en (0, 18, -9) | — (es un Model) |
| Floor1 | 40 × 1 × 20 | (0, 0.5, -9) | WoodPlanks #8B5A2B |
| Floor2 | 40 × 1 × 20 | (0, 12.5, -9) | WoodPlanks |
| Floor3 | 40 × 1 × 20 | (0, 24.5, -9) | WoodPlanks |
| Posts (6) | Cylinder diámetro 2, alto 36 | X ∈ {-20, 0, 20}, Z ∈ {-19, 1}, Y = 18 | Wood #C9A24A, anillos oscuros cada 4 |
| BackWall | 40 × 36 × 1 | (0, 18, -19) | Wood #E9C98A |
| Roof | 2 WedgeParts formando techo a dos aguas, de Y = 36 a Y = 46, sobresale 3 por cada lado | — | Fabric #D9A441 |
| RoofFringe | fila de Parts 1 × 3 × 0.5 cada 1.5 stud en el borde frontal | Y ≈ 35 | Fabric #C48A2C |
| Ladder | 4 de ancho, de Y=0 a Y=25, en el costado derecho | (22, 12.5, -9) | Wood + TrussPart |
| Sign | 18 × 4 × 1 | (0, 33, 1.5) | WoodPlanks; SurfaceGui con el nombre del dueño |
| TikiMasks (2) | 3 × 4 × 1 | en los postes del frente, Y = 30 | Wood #A0522D + Decal |
| Torches (2) | modelo TikiTorch | (-26, 0, 6) y (26, 0, 6) | — |
| SpawnPoint | Part invisible 4 × 1 × 4 | (0, 1, 6) | para teletransportar al dueño |

### 6.3 Estantes (Shelves) — donde van las criaturas
- 5 estantes por piso, 15 en total. Cada estante es un pad de 6 × 0.5 × 6, color #FFE27A (desbloqueado) o #5B4AB8 (bloqueado).
- Posición local X ∈ {-16, -8, 0, 8, 16}, Z = -13, Y = 1.25 / 13.25 / 25.25 según el piso.
- Nombre: `Shelf_<piso>_<n>` (ej. `Shelf_1_3`). Atributo `Unlocked` (bool).
- **Piso 1** desbloqueado desde el inicio. **Piso 2** con el 1er renacimiento. **Piso 3** con el 2º renacimiento.
- Pisos bloqueados: pared frontal `LockBarrier` 40 × 11 × 0.5 en Z = 1, material ForceField, color #7FD6E8, CanCollide true, con un candado (BillboardGui 🔒 o Decal). Se elimina al desbloquear.

### 6.4 Incubadoras (3, ADELANTE de la base) ⭐
Están entre la torre y el lobby, a 10 studs del frente de la torre.

| Incubadora | Posición local del centro |
|---|---|
| Incubator1 | (-14, 0, 15) |
| Incubator2 | (0, 0, 15) |
| Incubator3 | (14, 0, 15) |

Cada incubadora es un Model:
| Part | Tamaño | Posición local (respecto al centro de la incubadora) | Material/color |
|---|---|---|---|
| Pedestal | 8 × 2 × 8 | (0, 1, 0) | Slate #8E857A |
| NestBase | Cylinder diámetro 7, alto 1.5 | (0, 2.75, 0) | WoodPlanks #7A4A1E |
| NestRim | 10 Wedges pequeñas en anillo (radio 3.2), inclinadas hacia afuera | Y ≈ 3.6 | Fabric #E3B65A (paja) |
| EggSlot | Attachment | (0, 4.5, 0) | donde se suelda el huevo |
| GlowLight | PointLight | dentro de NestBase | color = rareza del huevo, Range 10; apagada si está vacía |
| Sparkles | ParticleEmitter | en EggSlot | color = rareza, Rate 5; solo mientras incuba |
| Prompt | ProximityPrompt | en Pedestal | ActionText "Poner huevo" / "Abrir"; KeyCode E; HoldDuration 0.5; MaxActivationDistance 10 |
| TimerGui | BillboardGui | Adornee = EggSlot, StudsOffset (0, 4, 0), Size 6 × 2 | muestra "00:45", "¡LISTO!" o "VACÍO" |

Atributos del Model: `State` = "Empty" | "Incubating" | "Ready", `EggRarity` (string), `EndTime` (número, os.time()).

Estados:
- **Empty**: luz apagada, Billboard gris "VACÍO", prompt "Poner huevo" (solo si el jugador lleva huevo).
- **Incubating**: huevo en el nido, luz y partículas de la rareza, Billboard azul oscuro (#0A1F4D) con cuenta regresiva.
- **Ready**: el huevo se agrieta (cambiar a mesh agrietado o agregar Decal), Billboard dorado (#C98A00) "¡LISTO!", prompt "Abrir". Al abrir: explosión de confeti del color de la rareza, sonido "pop", la criatura va al primer Shelf libre.

Solo el dueño de la base puede usar sus incubadoras.

---

## 7. Cañón del tsunami

### 7.1 Piso (6 zonas)
Ancho del camino: **80** (Z de -40 a 40). Largo total: **1200** (X de 150 a 1350).

| Zona | Nombre | X desde → hasta | Centro Part piso | Tamaño | Material/color |
|---|---|---|---|---|---|
| 1 | Playa | 150 → 350 | (250, -1, 0) | 200 × 2 × 80 | Sand #F2D49B |
| 2 | Selva | 350 → 550 | (450, -1, 0) | 200 × 2 × 80 | Grass #7CC46B |
| 3 | Rocas | 550 → 750 | (650, -1, 0) | 200 × 2 × 80 | Slate #ABA294 |
| 4 | Basalto | 750 → 950 | (850, -1, 0) | 200 × 2 × 80 | Basalt #6E6863 |
| 5 | Lava fría | 950 → 1150 | (1050, -1, 0) | 200 × 2 × 80 | CrackedLava #4A3833 |
| 6 | Obsidiana | 1150 → 1350 | (1250, -1, 0) | 200 × 2 × 80 | Slate #261F33 |

En cada cambio de zona: un **cartel de madera** (poste + tabla 8 × 3 × 0.5) pegado a la pared norte con el nombre de la zona y su rareza, en X = inicio de zona + 5, Z = -36.

### 7.2 Paredes
- Pared norte: de Z = -40 a Z = -60 (20 de grosor), alto 40 (Y de 0 a 40). Pared sur: de Z = 40 a Z = 60.
- Material Rock #7A6E62. Arriba de cada pared, una franja de selva: Parts LeafyGrass #2F8A3C de 20 × 4 × 20 en Y = 42, más **copas de árboles** (esferas verdes diámetro 10–16, colores #3F9A48 / #2F8A3C / #4FAE52) cada ~12 studs, desordenadas.
- Las paredes se construyen en **segmentos**, dejando huecos donde van las cuevas.
- Paredes invisibles extra de 100 de alto encima (Transparency 1) para que nadie se salga del cañón.

### 7.3 Cuevas-refugio (12)
Hueco en la pared de **12 (X) × 12 (Y) × 10 (Z de profundidad)**. Más separadas en las zonas lejanas.

| Cueva | X centro | Pared | Zona | Nota |
|---|---|---|---|---|
| Cave01 | 200 | Norte | Playa | |
| Cave02 | 260 | Sur | Playa | |
| Cave03 | 320 | Norte | Playa | |
| Cave04 | 400 | Sur | Selva | |
| Cave05 | 480 | Norte | Selva | **VIP**: 20 de ancho, marco dorado Neon #F5B800, solo jugadores con el GamePass VIP (los demás chocan con una pared invisible) |
| Cave06 | 560 | Sur | Rocas | |
| Cave07 | 660 | Norte | Rocas | |
| Cave08 | 760 | Sur | Basalto | |
| Cave09 | 880 | Norte | Basalto | |
| Cave10 | 1000 | Sur | Lava fría | |
| Cave11 | 1150 | Norte | Obsidiana | |
| Cave12 | 1300 | Sur | Obsidiana | |

Cada cueva (Model):
- Hueco en la pared interior (Z de -40 a -50 para el norte; de 40 a 50 para el sur), alto 12.
- `CaveBack`: tapa del fondo en la mitad exterior de la pared (la pared sigue maciza detrás).
- `CaveCeiling`: Part de 12 × 28 × 10 de Y = 12 a Y = 40 sobre el hueco.
- `CaveFrame`: marco de arco con 3 Parts de 1.5 de grosor, WoodPlanks #8A6A4A (dorado Neon en la VIP).
- `CaveTorch`: una antorcha tiki adentro para verla de lejos (PointLight Range 14).
- `SafeZone`: Part invisible, CanCollide false, Transparency 1, tamaño 12 × 12 × 10, llenando el hueco. Atributo `Safe = true`. **Si el HumanoidRootPart de un jugador está dentro de una SafeZone cuando pasa la ola, está a salvo.**

### 7.4 Decoración por zona (aleatoria con semilla fija; dejá libre 6 studs alrededor de cada cueva y de cada EggSpawn)
| Zona | Qué poner | Cantidad |
|---|---|---|
| Playa | conchas, estrellas de mar, 2 palmeras pegadas a las paredes, maderas de naufragio | 20 detalles + 2 palmeras |
| Selva | arbustos (esferas aplastadas Grass), helechos, flores de hibisco, lianas colgando de las paredes (Parts finas verdes) | 15 arbustos + 10 lianas |
| Rocas | rocas grandes (Parts rotadas Slate #8E857A, 4–10 de tamaño) | 12 |
| Basalto | columnas hexagonales Basalt #4B4642 de alto 3–14 (cilindros de 6 lados o MeshPart) en grupos de 3–5 | 8 grupos |
| Lava fría | grietas: Parts Neon #FF6A1A de 0.4 de alto hundidas en el piso, en zigzag; humo (Smoke) en 4 de ellas | 10 grietas |
| Obsidiana | cristales: Wedges Glass #A35BFF de alto 4–10 con PointLight violeta (Range 8) | 10 grupos |

---

## 8. Mar, volcán y ola

### 8.1 Mar e Isla v2 (Terrain)
- Agua de Terrain hasta Y = -1.5 alrededor de todo, fondo de arena en Y = -32.
- **Isla v2** (la arma `IslandBuilder` con Terrain, números en `Config.Island`): el lobby y las bases quedan en el oeste de una isla grande (pasto), el cañón cruza colinas con selva (acantilados de roca al lado de las paredes) y termina contra el volcán, al este.
- Formas de la costa: lóbulo oeste (faro y barco hundido en la punta noroeste), franja central, **caleta norte** (laguna con cascada), **península sur** (muelle con 2 botes) y el lóbulo del volcán. Playa alrededor, arrecifes y rocas en el agua baja.
- El lobby y el cañón **no se tocan**: el terreno queda abajo de sus Parts; alrededor del lobby el piso es plano y sube de a poco.
- Paredes invisibles arriba de las paredes del cañón y en su final: al cañón solo se entra por el portal.
- Colores de Terrain: arena #F0DCAA, pasto #6CC04A, selva #2E8B3E, roca #8F8A85, basalto #4A4440, lava #FF6A1A.

### 8.2 Volcán (Terrain)
- Centro en **(1600, 0, 0)**: el cañón (que termina en X = 1350) choca contra su ladera.
- Forma: alto = **330 × (1 − r/380)^1.55**, cortado a **240** (borde del cráter, r ≈ 71). Cráter hundido **38 studs** con un lago de lava (Part Neon) a Y = 206.
- Laderas curvas (empinadas arriba, suaves abajo) con 9 barrancos. Colores por altura: selva (abajo) → roca y pasto → basalto → piedra oscura (Slate) en la cumbre.
- 3 ríos de lava tallados en el terreno (CrackedLava); brillan arriba (Parts Neon) y se oscurecen al bajar.
- Humo enorme (`VolcanoSmoke`, más fuerte durante la ola) + brasas (`VolcanoEmbers`). Niebla de Atmosphere que tapa el horizonte.

### 8.3 Ola (Part `Wave`)
- Tamaño **6 (X) × 50 (Y) × 84 (Z)**. Material Glass o SmoothPlastic, color #A8EEF6, Transparency 0.3.
- En el frente: ParticleEmitter de espuma blanca.
- Arranca en X = 1360 y avanza en -X hasta **X = 150** (el portal). **No entra al lobby.** Después se desvanece.
- Colisión: CanCollide false; usar `GetPartsInPart` / Touched para detectar jugadores.

| Tipo | Cada cuánto | Velocidad | Aviso antes |
|---|---|---|---|
| Normal | 60–90 s (aleatorio) | 60 studs/s (~20 s en cruzar) | 5 s |
| Rápida | al azar, 1 de cada 4 olas | 120 studs/s | 3 s |
| Súper tsunami (evento) | cada 30 min | 90 studs/s, alto 80 | 15 s + anuncio |

Secuencia de cada ola:
1. Aviso: el volcán echa más humo, la cámara tiembla un poco (todos los jugadores en el cañón), suena un **cuerno de caracol**, texto en pantalla "¡SE VIENE LA OLA!".
2. La ola recorre el cañón con sonido de rugido.
3. Jugador tocado y **sin** SafeZone → pierde el huevo que llevaba y se teletransporta al SpawnLocation del lobby.

---

## 9. Modelos de decoración (`ServerStorage/Props`)

### 9.1 Palm
- Tronco: 6 Cylinders de diámetro 2.2 → 1.6 (se afinan), cada uno 3.5 de alto, rotados 4–6° más que el anterior para que se curve. Wood #8B5A2B.
- Hojas: 6 WedgeParts verdes (#2E9E44, LeafyGrass) de 10 × 0.4 × 3, en estrella desde la punta, inclinadas 25° hacia abajo.
- Cocos: 3 esferas de diámetro 1.2, #7A4A1E.

### 9.2 TikiTorch
- Palo: 0.8 × 7 × 0.8, Wood #7A4A1E.
- Canasta: Cylinder diámetro 2, alto 1.5, Wood #C9A24A, en la punta.
- Fuego: objeto `Fire` (Size 3, Heat 6, Color #FF8A1F, SecondaryColor #FFE27A).
- `PointLight`: #FF8A1F, Range 14, Brightness 2, Shadows true.

### 9.3 Rock
Part de 4–10 por lado, rotada al azar, Slate #8E857A, con 1–2 rocas chicas al lado.

### 9.4 Crystal
3 Wedges Glass #A35BFF (alto 4, 7 y 10) apuntando hacia arriba en abanico + PointLight #A35BFF Range 8.

### 9.5 Stall (puesto de playa)
- Base: 24 × 6 × 14, Wood #E9C98A.
- Mostrador: 26 × 1 × 4 al frente, a Y = 6, WoodPlanks #8B5A2B.
- 4 postes de bambú de alto 14 en las esquinas.
- Toldo a rayas: 8 Parts de 3 × 0.4 × 16 alternando color del puesto y blanco, inclinado 15°, a Y = 14.
- Cartel: 14 × 3 × 0.5 arriba del toldo con SurfaceGui (nombre del puesto).

---

## 10. Huevos en el cañón

### 10.1 EggSpawns
- Por cada zona, una carpeta `EggSpawns/ZoneN` con Parts invisibles de 2 × 1 × 2 (CanCollide false, Transparency 1).
- Puestos en grilla con algo de desorden, mínimo 15 studs entre sí, nunca a menos de 6 de una cueva.

| Zona | Cantidad de spawns | Huevos activos al mismo tiempo | Reaparición |
|---|---|---|---|
| 1 Playa | 16 | 8 | 10 s |
| 2 Selva | 14 | 6 | 15 s |
| 3 Rocas | 12 | 5 | 20 s |
| 4 Basalto | 10 | 4 | 30 s |
| 5 Lava fría | 8 | 3 | 45 s |
| 6 Obsidiana | 6 | 1 | 90 s |

### 10.2 Rarezas (`ReplicatedStorage/Config/Rarities`)
Cada zona da huevos **de su rareza** (90%) o de la siguiente (10%). Ejemplo: Zona 3 → 90% Épico, 10% Legendario. Zona 6 → 100% Secreto.

| Rareza | Tiempo de incubación base | Dinero/s de la criatura (sugerido) |
|---|---|---|
| Común | 30 s | 1 |
| Raro | 60 s | 5 |
| Épico | 180 s | 25 |
| Legendario | 480 s | 120 |
| Mítico | 1200 s | 600 |
| Secreto | 2700 s | 3000 |

### 10.3 Huevo en el piso
- Tamaño 2.5 × 3.2 × 2.5 (esfera escalada o MeshPart), Neon o SmoothPlastic del color de la rareza.
- Gira 45°/s en Y, flota subiendo y bajando ±0.4 (TweenService).
- PointLight del color de la rareza, Range 8.
- ProximityPrompt "Agarrar" (HoldDuration 0.3). Al agarrarlo, el huevo se suelda a la mano derecha del personaje. Solo 1 a la vez.

---

## 11. Sonidos (SoundService / en las Parts)

| Sonido | Dónde | Volumen |
|---|---|---|
| Música tiki (tambores suaves, loop) | Lobby (Sound en SoundService, se baja en el cañón) | 0.3 |
| Olas de mar (loop) | Ocean / costa | 0.4 |
| Cuerno de caracol | aviso de ola, global | 0.8 |
| Rugido de ola | en la Part Wave | 1.0 |
| Retumbe de volcán | Volcano, en la erupción | 0.7 |
| Pop + campanita | al abrir un huevo | 0.6 |
| Fuego crepitando | en cada TikiTorch, RollOffMaxDistance 30 | 0.2 |

Usar sonidos libres de la Creator Store de Roblox.

---

## 12. Orden de construcción recomendado

1. Lighting + agua (§4, §8.1).
2. Piso del lobby y terrazas (§5.1).
3. Altar + SpawnLocation (§5.2).
4. Cañón: pisos, paredes con huecos, cuevas con SafeZone (§7.1–7.3).
5. Bases 1–8 con torre, estantes e **incubadoras adelante** (§6).
6. Puestos y portal (§5.3–5.5).
7. Volcán y ola (§8.2–8.3).
8. Props y decoración (§9, §5.6, §7.4).
9. EggSpawns y huevos (§10).
10. Sonidos (§11).

## 13. Checklist para verificar

- [ ] Las 8 bases miran al altar y cada una tiene **exactamente 3 incubadoras adelante**.
- [ ] Desde el SpawnLocation se ve el portal y, al fondo, el volcán.
- [ ] La ola recorre de X = 1360 a X = 150 y nunca entra al lobby.
- [ ] Parado dentro de cualquier cueva (incluida la VIP con pase), la ola no te afecta.
- [ ] Las cuevas están más separadas a medida que avanzás.
- [ ] Todos los colores y materiales salen de la tabla del §3.
- [ ] Ninguna decoración tapa un EggSpawn ni la entrada de una cueva.
- [ ] Todas las Parts están Anchored.

> Referencia visual: el canvas "Mapa del juego de huevos" (tableros 1 a 7).
