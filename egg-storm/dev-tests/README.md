# Pruebas automáticas (opcional, para desarrollo)

Estas pruebas corren el código REAL del juego fuera de Roblox, con una imitación mínima de la API de Roblox
(reloj falso, señales, jugadores, DataStore con fallas a propósito). No hacen falta para jugar ni para publicar.

Requisitos: el intérprete `luau` (https://github.com/luau-lang/luau/releases) y Python 3 con `matplotlib`.

Desde la carpeta `egg-storm`:

```
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_phase3.luau   # incubadoras y mascotas
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_phase4.luau   # mejoras
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_phase5.luau   # tormenta y ola
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_phase7.luau   # guardado
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_phase8.luau   # partida completa con 2 jugadores
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_sell.luau     # vender mascotas
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_tutorial.luau # tutorial
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_offline.luau  # ganancia mientras no estás
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_leaderboard.luau # tablas de récords
python3 dev-tests/flow.py src <ruta-a-luau> dev-tests/test_stairs.luau > salida.txt   # escalera del piso 2
python3 dev-tests/render_parts.py salida.txt escalera.png                            # dibujo de la escalera
python3 dev-tests/bundle.py src <ruta-a-luau> mapa.png                   # dibujo del mapa desde arriba
python3 dev-tests/ui_render.py src <ruta-a-luau> dev-tests/ui_upgrades.luau mejoras.png 1280 720   # interfaz
```

Cada prueba termina con `ALL PASSED` o con la lista de lo que falló.
