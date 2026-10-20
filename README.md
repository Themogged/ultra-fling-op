# NOVA MASTER SUITE v6.0

Suite cliente Luau para Roblox que integra `FLING`, `GUARD` y el control opcional de `COUNTER` en una sola interfaz compacta.

> Úsalo únicamente en experiencias privadas propias o con participantes que hayan aceptado las pruebas. El comportamiento físico final depende de la autoridad de red del servidor, del juego y de sus protecciones.

## Carga RAW

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Themogged/ultra-fling-op/main/Nova_Master_Suite_v6.lua", true))()
```

Archivo RAW directo:

<https://raw.githubusercontent.com/Themogged/ultra-fling-op/main/Nova_Master_Suite_v6.lua>

## FLING

- Selección individual, búsqueda y selección total de jugadores.
- Detección de `Humanoid.SeatPart`, `Occupant`, `SeatWeld` y `VehicleSeat`.
- Modo adaptativo para objetivos a pie, sentados o dentro de vehículos.
- Cinco niveles de potencia: `ORIGINAL`, `NORMAL`, `FUERTE`, `ULTRA` y `TEORICO`.
- Conserva las magnitudes de velocidad y rotación de NOVA FLING v5 en el modo `ORIGINAL`.
- Seguimiento de ensamblajes físicos conectados y predicción de movimiento.
- Worker único cancelable, reinicio seguro y recuperación del personaje.

## GUARD

- Monitor local de velocidad, rotación y cambios bruscos de movimiento.
- Modos `SAFE`, `SMART` y `SENSITIVE`.
- Registro visual de amenazas y contador de intentos.
- Recuperación opcional desde un punto seguro reciente.
- Suspensión automática mientras el worker de FLING está activo para evitar conflictos.

## COUNTER

La interfaz cliente detecta un módulo servidor opcional llamado `NOVA_Counter`, solicita su activación y espera confirmación del servidor antes de mostrarlo como activo.

`NOVA_Counter.server.lua` **no está incluido en el archivo proporcionado ni en esta publicación**. Debe instalarse por separado y únicamente dentro de una experiencia Roblox que controles. Sin ese componente, la interfaz mostrará `COUNTER: NO DISPONIBLE`.

## Interfaz

- Tema rojo, negro y dorado con pestañas para `FLING`, `GUARD` y `COUNTER`.
- Ventana arrastrable en móvil y PC, ajustada al área visible.
- Modo compacto al minimizar y atajo `RightShift` para mostrar u ocultar.
- Sin cargas remotas adicionales dentro del script publicado.

## Uso

1. Ejecuta la línea de carga RAW en un entorno compatible con `loadstring` y `game:HttpGet`.
2. Usa la pestaña **FLING** para seleccionar objetivos y elegir la potencia.
3. Configura la protección local desde **GUARD**.
4. Usa **COUNTER** solamente si instalaste el componente servidor compatible en tu propia experiencia.

## Compatibilidad y límites

- Debe ejecutarse en el cliente de Roblox.
- Un `LocalScript` no puede obligar al servidor a mover objetos cuya simulación de red pertenece a otro cliente o al servidor.
- Los resultados pueden variar según el juego, la propiedad de red, piezas ancladas, sistemas antitrampas y cambios de la plataforma.
- Los modos `ORIGINAL` y `TEORICO` usan valores extremos y pueden producir movimientos inestables.
- La atribución de amenazas de `GUARD` es heurística y puede producir falsos positivos.
- El cliente no implementa por sí solo la lógica servidor de `COUNTER`.

## Versiones

- `Nova_Master_Suite_v6.lua`: versión actual y recomendada.
- `Nova_Fling_v5.lua`: versión anterior conservada para referencia y compatibilidad.
- `Ultra_Fling_OP_v4.lua`: versión anterior conservada para referencia y compatibilidad.

## Validación

Los archivos publicados se validan con el compilador oficial Luau antes de cada actualización.
