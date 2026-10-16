# Pruebas automáticas (opcional, para desarrollo)

Estas pruebas corren el código REAL del juego fuera de Roblox, con una imitación mínima de la API de Roblox
(reloj falso, señales, jugadores, DataStore con fallas a propósito). No hacen falta para jugar ni para publicar.

Requisitos: el intérprete `luau` (https://github.com/luau-lang/luau/releases) y Python 3 con `matplotlib`.

Desde la carpeta `egg-storm`:

```
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_map.luau         # el mapa respeta MAPA_SPEC (bases, cuevas, puntos de huevos...)
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_eggs.luau        # huevos por zona, reaparición, variantes, meteoritos
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_incubators.luau  # nidos: poner huevo, READY!, abrir, estantes
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_waves.luau       # olas, cuevas-refugio, súper tsunami, ola rápida
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_upgrades.luau    # Tienda de mejoras
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_tower.luau       # torre de 3 pisos, candados y escalera
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_lobby.luau       # puestos del lobby y tablero de eventos
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_events.luau      # eventos (Golden Rain, Lucky Storm...)
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_sell.luau        # vender mascotas
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_save.luau        # guardado
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_game.luau        # partida completa con 2 jugadores
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_tutorial.luau    # tutorial
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_offline.luau     # ganancia mientras no estás
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_leaderboard.luau # tablas de récords
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_rebirth.luau     # renacimiento
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_merchant.luau    # Comerciante misterioso
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_trade.luau       # intercambio entre jugadores
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_vip.luau         # pase VIP y cueva VIP
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_island.luau      # isla v2 de Terrain y volcán
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_tower.luau > salida.txt   # (también imprime las piezas de 2 bases)
python3 dev-tests/render_parts.py salida.txt bases.png                               # dibujo de las bases
python3 dev-tests/bundle.py src <ruta-a-luau> mapa.png                               # dibujo del mapa desde arriba
python3 dev-tests/island_preview.py src <ruta-a-luau> isla.png volcan.png           # isla v2 (terreno) y corte del volcán
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_tower.luau > salida.txt && python3 dev-tests/render3d.py salida.txt base.png -117,15,-142 -164,40,-72 45   # base en 3D
python3 dev-tests/ui_render.py src <ruta-a-luau> dev-tests/ui_upgrades.luau mejoras.png 1280 720   # interfaz
```

Cada prueba termina con `ALL PASSED` o con la lista de lo que falló.
