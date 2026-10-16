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
6. La criatura vive suelta en el **hábitat** de la base (20 lugares) y genera dinero por segundo.
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
    │   ├── Ground            (piso de pasto + terrazas de los hábitats)
    │   ├── Altar
    │   ├── Stalls            (UpgradeShop, Merchant, Rankings, Trading)
    │   ├── Path              (camino de piedras al portal)
    │   ├── Portal
    │   └── Village           (Moat con 4 Bridges, Lagoon, GiantTree, FirePit, EggGarden, Boardwalk, DirtPath, Jungle)
    ├── Bases
    │   ├── Base1 … Base8     (cada una: Ground/Plot, Wall, Entrance, Water, Shelter, Grottos, Jungle,
    │   │                      IncubatorSlots, CreatureSlots, InfoSign, SpawnPoint, SafeZone)
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

## 5. Lobby — Aldea de la selva

> Lo arman `MapBuilder.luau` (piso, altar, puestos, camino y portal) y `VillageBuilder.luau` (todo lo demás).
> Las medidas principales están en `Config.Village`. Vista desde arriba: -Z = norte (arriba), +X = hacia el cañón.

```
            Hábitats 1-4 (en la selva) ── pasarela de madera Z = -116 ──
   Laguna con cascada (-105,-72)                     Fogón tiki + escenario (100,-76)
             TIENDA (-44,-44)        │        RANKINGS (44,-44)
                         ~~~~ foso ~ puente N ~ foso ~~~~
   ── camino ── puente O ─  ALTAR (0,0,0)  ─ puente E ── camino de piedras ──▶ PORTAL (150, 0)
                         ~~~~ foso ~ puente S ~ foso ~~~~
         COMERCIANTE (-44,44)        │        INTERCAMBIO (44,44)
   Árbol gigante + casita (-105,72)                  Jardín de los huevos (100,74)
            Hábitats 5-8 (en la selva) ── pasarela de madera Z = 116 ──
```

### 5.1 Piso
| Part | Tamaño | Posición (centro) | Material/color |
|---|---|---|---|
| LobbyGrass | 300 × 2 × 420 | (0, -1, 0) | Grass #6CC24A |
| Terrace (norte y sur) | 300 × 2.2 × 90 | (0, -0.9, ±165) | Grass #5DB33D (donde están los hábitats) |
| PlazaStone | disco de diámetro 60 | (0, 0, 0), arriba en Y = 0.15 | Slate #D6C4A0 |

### 5.2 Altar del volcán (spawn) — centro (0, 0, 0)
| Part | Forma | Tamaño | Posición | Material/color |
|---|---|---|---|---|
| AltarRing | Cylinder (acostado en Y) | diámetro 34, alto 2 | (0, 1, 0) | Slate #8E857A |
| AltarRingEdge | Cylinder | diámetro 36, alto 1.5 | (0, 0.75, 0) | Slate #5E5751 |
| LavaPool | Cylinder | diámetro 18, alto 0.4 | (0, 2.1, 0) | Neon #FF6A1A |
| Pedestal | Block | 6 × 6 × 6 | (0, 5, 0) | Slate #8E857A |
| GoldenEgg | Sphere escalada a 5 × 7 × 5 | — | (0, 11.5, 0) | Neon #FFD84D, gira 20°/s en Y y sube/baja ±0.5 |
| SpawnLocation | 12 × 1 × 12, invisible | (0, 2.5, 22) | Transparency 1 |

- **8 antorchas tiki** en círculo de radio 22 alrededor del altar. Luz y chispas en la pileta de lava.

### 5.3 Foso y puentes
- **Foso** de agua entre el radio 30 y el 40 (40 tramos `Water`, Glass #3FD8F0, transparencia 0.25, **no choca**: se cruza mojándose los pies), fondo #28AAD2 y bordes de piedra por dentro y por fuera.
- Nenúfares (#46AA46) con flores de loto rosas y peces koi naranjas con manchas blancas.
- **4 puentes** de madera (N, S, E, O), de 8 de ancho, del radio 27 al 43, arqueados (1.6 de alto en el medio), con barandas de soga y un farol en cada punta.

### 5.4 Puestos (Stalls) — en diagonal, del otro lado del foso
Modelo base 24 × 16 × 14 (§9.5), frente mirando al altar, a 62 del centro (`Config.Village.StallRadius`).

| Puesto | Posición del centro | Color toldo |
|---|---|---|
| UpgradeShop | (-43.8, 0, -43.8) | #1E88E5 + blanco |
| Merchant | (-43.8, 0, 43.8) | #8E3FD6 + blanco |
| Rankings | (43.8, 0, -43.8) | #E8590C + blanco |
| Trading | (43.8, 0, 43.8) | #0F9D8A + blanco |

- Rankings: tablero de récords de plata arriba, de huevos abiertos a un costado y el **tablero de eventos** al otro.
- Cada puesto tiene un ProximityPrompt en el mostrador que abre su ventana (las mismas ventanas también se abren desde el HUD).

### 5.5 Rincones
| Rincón | Centro | Qué tiene |
|---|---|---|
| Laguna con cascada (arriba a la izquierda) | (-105, -72) | Agua de diámetro 44 con arena alrededor; acantilado de 26 × 24 con **cascada** y niebla; 7 piedras para cruzar (se pisan); 3 flamencos; juncos, nenúfares, 2 bancos y mariposas. |
| Árbol gigante (abajo a la izquierda) | (-105, 72) | Tronco de diámetro 9 y 44 de alto con raíces, ramas y copa enorme; **plataforma** redonda (diámetro 32) a Y = 22 con baranda y **casita de paja**; **escalera de soga** (TrussPart, se trepa) con cartel "CLIMB ↑"; columpio; lianas con faroles; hongos que brillan y luciérnagas. |
| Fogón tiki (arriba a la derecha) | (100, -76) | Fogata con aro de piedras, fuego, chispas y luz; **3 filas de troncos** (18) en semicírculo; **escenario** de 26 × 12 detrás, con máscara tiki gigante (ojos que brillan, plumas de colores), 3 tambores y 2 faroles. |
| Jardín de los huevos (abajo a la derecha) | (100, 74) | Pasto en un círculo de diámetro 58; los **6 huevos gigantes** (6 × 8 × 6) de las rarezas, de Common a Secret, en nidos de paja con cartel; Legendary, Mythic y Secret son de Neon, giran y tienen luz y brillitos; flores gigantes y un **arco de flores** con el cartel "EGG GARDEN" mirando a la plaza. |

### 5.6 Caminos
- **Camino de piedras** (Cylinder diámetro 5, Slate #B8B0A3) a lo largo de Z = 0, desde el puente este (X = 46) hasta X = 145, uno cada 8 studs.
- **Pasarela de madera** (8 de ancho): de los puentes norte y sur hasta Z = ±112, y a lo largo de Z = ±116 de X = -146 a 146, con faroles cada 35. Un tramo de 6 de ancho llega a la entrada de cada hábitat.
- **Caminito de tierra** del puente oeste a la laguna y al árbol gigante.
- Nada sólido tapa los puentes, la pasarela ni el camino al cañón (lo revisa `test_lobby.luau`).

### 5.7 Portal tiki — entrada del cañón (X = 150)
| Part | Tamaño | Posición | Material/color |
|---|---|---|---|
| TotemNorth | 6 × 18 × 6 | (150, 9, -44) | Wood #A0522D, cara tallada (ojos #FFE27A) |
| TotemSouth | 6 × 18 × 6 | (150, 9, 44) | igual |
| Beam | 4 × 3 × 96 | (150, 19.5, 0) | WoodPlanks #8B5A2B |
| Sign | 2 × 4 × 24 | (149, 16, 0) | WoodPlanks, SurfaceGui: "TO THE CANYON ⚠" / "SAFE ISLAND" |
| Antorchas | 2 | (146, 0, ±50) | modelo TikiTorch |

### 5.8 Selva entre los hábitats
- Árboles de hojas anchas entre un hábitat y otro (X = -150, -75, 0, 75, 150; Z = ±140/±160) y detrás (Z = ±202).
- Helechos y monsteras al borde de la pasarela (sin tapar las entradas) y luciérnagas.

---

## 6. Bases de jugadores (8) — Hábitats de selva

> Cada base es un **hábitat de selva** redondo (lo arma `HabitatBuilder.luau`, ~400 piezas). Las criaturas viven sueltas
> adentro y pasean alrededor de su lugar (`CreatureWander.luau` en el cliente). **20 lugares por jugador desde el principio**
> (`Config.Habitat.Capacity`): no hay pisos, estantes ni mejoras de espacio.

### 6.1 Ubicación
Cada hábitat ocupa un círculo de unos **70 de diámetro**. El FRENTE (la entrada) mira al centro del lobby.

| Base | Centro | Frente mira hacia |
|---|---|---|
| Base1 | (-112.5, 0, -165) | +Z |
| Base2 | (-37.5, 0, -165) | +Z |
| Base3 | (37.5, 0, -165) | +Z |
| Base4 | (112.5, 0, -165) | +Z |
| Base5 | (-112.5, 0, 165) | -Z |
| Base6 | (-37.5, 0, 165) | -Z |
| Base7 | (37.5, 0, 165) | -Z |
| Base8 | (112.5, 0, 165) | -Z |

Coordenadas **locales** mirando el hábitat desde el lobby: **-Z = adelante** (la entrada), +Z = atrás (la cascada), **+X = derecha**.

### 6.2 Partes del hábitat (coordenadas locales)
| Parte | Dónde | Qué es |
|---|---|---|
| Plot (PrimaryPart) | (0, 0.1, 0) | invisible, mira al lobby |
| Ground | disco de radio 33 | pasto, lomitas y un sendero de tierra de la entrada al centro |
| Wall | anillo de 30 rocas en el radio 31 | bajas adelante (~6) y altas atrás (~24), con musgo, selva arriba y lianas; hueco de ±17° en la entrada, con brazos de roca que se abren hacia afuera |
| Entrance | Z = -32 | 2 pilares de piedra con máscara tiki, antorchas, techito de paja, guirnalda de flores y el cartel `SignLabel` con el nombre del dueño |
| Water | atrás y a la izquierda | acantilado (Z ≈ 29) con **cascada de 2 saltos** y niebla, pozo (3, 18), arroyo con **tronco de puente** y **lago** con arena, nenúfares y juncos en (-13, -6) |
| Shelter | (-14, 13) | terraza de piedra con refugio de paja, cama de heno y farol; 2 comederos; tronco caído |
| Grottos | en el muro, a -125° y 130° | arco de piedra con cortina de lianas: una con hongos que brillan y otra con cristales |
| Jungle | adentro, cerca del muro | 3 árboles de copa ancha, 2 palmeras, hojas gigantes, monsteras, helechos, arbustos y hongos |
| IncubatorSlots | a la derecha de la entrada | altar de piedra con los 3 nidos: Nest1 (11, -19), Nest2 (17.5, -10.5), Nest3 (21, -1.5) |
| CreatureSlots | por el pasto | 20 lugares invisibles `Spot_1`…`Spot_20` (SlotIndex 1-20, a 4.5 o más uno de otro), lejos del agua, la terraza, los árboles y los nidos; cada uno con su `WanderRadius` (hasta 6) para pasear sin meterse al agua ni al muro |
| InfoSign | (-12, -36) | cartel "🐾 7/20 · +$120/s" (`InfoLabel`, lo actualiza CreatureService) |
| SpawnPoint | (0, 0.5, -25) | invisible, justo adentro de la entrada |
| SafeZone | todo el hábitat | invisible, 68 × 60 × 68 |

### 6.3 Incubadoras (3 nidos)
Cada nido (`Nest1`-`Nest3`) es un Model con:
| Part | Tamaño | Material/color |
|---|---|---|
| Pedestal | 7 × 2 × 7 (atributo `SlotIndex`) | Slate #8E857A |
| NestBase | Cylinder diámetro 6.5, alto 1.5 | WoodPlanks #704C2C |
| NestRim | 10 bloques de paja en anillo, inclinados | Fabric #D9A441 / #C48A2C |

Lo demás lo agrega `IncubatorService` al armar la base: EggSlot, GlowLight, Sparkles, ProximityPrompt y el cartelito `TimerGui`
("00:45" azul, "READY!" dorado, "EMPTY" gris; "🔒 LOCKED" en los que no compraste). Los mismos estados se ven en el HUD.

Estados:
- **Empty**: luz apagada, "EMPTY", prompt "Place Egg" (solo si llevás un huevo).
- **Incubating**: huevo en el nido, luz y partículas de la rareza, cuenta regresiva.
- **Ready**: el huevo se agrieta, "READY!", prompt "Open". Al abrir: confeti del color de la rareza y la criatura aparece en el primer lugar libre del hábitat.

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
2. Piso del lobby, terrazas y plaza (§5.1).
3. Altar + SpawnLocation (§5.2).
4. Cañón: pisos, paredes con huecos, cuevas con SafeZone (§7.1–7.3).
5. Hábitats 1–8 con su muro de rocas, cascada, 20 lugares e **incubadoras adelante** (§6).
6. Foso, puentes, puestos, caminos y portal (§5.3–5.7).
7. Volcán y ola (§8.2–8.3).
8. Rincones de la aldea, selva y decoración (§5.5, §5.8, §9, §7.4).
9. EggSpawns y huevos (§10).
10. Sonidos (§11).

## 13. Checklist para verificar

- [ ] Los 8 hábitats miran al altar, cada uno con **3 nidos adelante** y **20 lugares** para criaturas adentro del muro.
- [ ] La pasarela llega a la entrada de cada hábitat y nada sólido tapa los puentes ni los caminos.
- [ ] Desde el SpawnLocation se ve el portal y, al fondo, el volcán.
- [ ] La ola recorre de X = 1360 a X = 150 y nunca entra al lobby.
- [ ] Parado dentro de cualquier cueva (incluida la VIP con pase), la ola no te afecta.
- [ ] Las cuevas están más separadas a medida que avanzás.
- [ ] Todos los colores y materiales salen de la tabla del §3.
- [ ] Ninguna decoración tapa un EggSpawn ni la entrada de una cueva.
- [ ] Todas las Parts están Anchored.

> Referencia visual: el canvas "Mapa del juego de huevos" (tableros 1 a 7).
