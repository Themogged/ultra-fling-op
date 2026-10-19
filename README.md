# Ultra Fling OP v4.0

Interfaz Luau para Roblox con selección de objetivos, búsqueda, distintos niveles de potencia y adaptación automática a personajes a pie, sentados o dentro de vehículos.

> Úsalo únicamente en experiencias privadas propias o con participantes que hayan aceptado las pruebas. El comportamiento físico final depende de la autoridad de red del servidor, del juego y de sus protecciones.

## Carga RAW

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Themogged/ultra-fling-op/main/Ultra_Fling_OP_v4.lua", true))()
```

Archivo RAW directo:

<https://raw.githubusercontent.com/Themogged/ultra-fling-op/main/Ultra_Fling_OP_v4.lua>

## Funciones principales

- Selección individual, búsqueda y selección total de jugadores.
- Detección de `Humanoid.SeatPart`, `Occupant`, `SeatWeld` y `VehicleSeat`.
- Modo adaptativo para objetivos a pie, sentados o dentro de vehículos.
- Cuatro niveles de potencia: `NORMAL`, `FUERTE`, `ULTRA` y `TEORICO`.
- Seguimiento de ensamblajes físicos conectados y predicción de movimiento.
- Worker único cancelable, reinicio seguro y recuperación del personaje.
- Interfaz arrastrable para móvil y PC, minimizable y con atajo `RightShift`.
- Sin dependencias externas ni cargas remotas adicionales.

## Uso

1. Ejecuta la línea de carga RAW en un entorno compatible con `loadstring` y `game:HttpGet`.
2. Selecciona uno o varios jugadores en la interfaz.
3. Elige la potencia adecuada.
4. Pulsa **INICIAR**. Puedes detener el proceso en cualquier momento con **DETENER**.

## Compatibilidad y límites

- Debe ejecutarse en el cliente de Roblox.
- Un `LocalScript` no puede obligar al servidor a mover objetos cuya simulación de red pertenece a otro cliente o al servidor.
- Los resultados pueden variar según el juego, la propiedad de red, piezas ancladas, sistemas antitrampas y cambios de la plataforma.
- El modo `TEORICO` es experimental y puede producir movimientos inestables.

## Validación

El archivo `Ultra_Fling_OP_v4.lua` fue compilado correctamente con el compilador oficial Luau 0.740 antes de su publicación.
