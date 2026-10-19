# NOVA FLING v5.0

Interfaz Luau compacta para Roblox con selección de objetivos, cinco niveles de potencia y adaptación automática a personajes a pie, sentados o dentro de vehículos.

> Úsalo únicamente en experiencias privadas propias o con participantes que hayan aceptado las pruebas. El comportamiento físico final depende de la autoridad de red del servidor, del juego y de sus protecciones.

## Carga RAW

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Themogged/ultra-fling-op/main/Nova_Fling_v5.lua", true))()
```

Archivo RAW directo:

<https://raw.githubusercontent.com/Themogged/ultra-fling-op/main/Nova_Fling_v5.lua>

## Funciones principales

- Selección individual, búsqueda y selección total de jugadores.
- Detección de `Humanoid.SeatPart`, `Occupant`, `SeatWeld` y `VehicleSeat`.
- Modo adaptativo para objetivos a pie, sentados o dentro de vehículos.
- Cinco niveles de potencia: `ORIGINAL`, `NORMAL`, `FUERTE`, `ULTRA` y `TEORICO`.
- Modo `ORIGINAL` con las magnitudes de velocidad y rotación del enfoque clásico.
- Seguimiento de ensamblajes físicos conectados y predicción de movimiento.
- Worker único cancelable, reinicio seguro y recuperación del personaje.
- Interfaz NOVA compacta, arrastrable en móvil y PC y limitada al área visible.
- Barra flotante al minimizar y atajo `RightShift` para mostrar u ocultar.
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
- Los modos `ORIGINAL` y `TEORICO` usan valores extremos y pueden producir movimientos inestables.

## Versiones

- `Nova_Fling_v5.lua`: versión actual y recomendada.
- `Ultra_Fling_OP_v4.lua`: versión anterior conservada para referencia y compatibilidad.

## Validación

Los archivos publicados se validan con el compilador oficial Luau antes de cada actualización.
