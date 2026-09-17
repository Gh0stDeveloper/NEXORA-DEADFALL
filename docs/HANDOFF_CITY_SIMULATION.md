# Ciudad, simulación y operadora — avance recuperable

Fecha de inicio: 2026-09-16. Proyecto: Gh0stDeveloper/NEXORA-DEADFALL.
Base comprobada: main `959a6cb53767718902b1eeb33feebf2848911644`.
El propietario confirmó que la actualización anterior ya funciona.
Rama de trabajo: `agent/city-simulation-upgrade`.

## Encargo

Ampliar el mapa a una ciudad con colores naturales, pasto, tierra, asfalto,
vehículos destruidos, fuego y edificios destruidos con interiores accesibles.
Corregir zombis inmóviles, mantener en el servidor solamente simulación,
colisiones, navegación, IA y red, y medir la causa del ping alto. Conservar
DANTE y sustituir la presentación del otro operador por una mujer.

## Fases y criterios de aceptación

- [x] 0. Recuperar la base y guardar este plan en una rama remota.
- [ ] 1. Persecución y servidor: hordas persiguen a jugadores aunque aparezcan
  fuera de su visión; navegan alrededor de obstáculos; el dedicado no instancia
  mallas, cámaras, luces, etiquetas 3D ni audio. Conservar colisiones autoritativas.
  Separar RTT de partida del tiempo HTTP del lobby, mostrar mediciones reales
  y obtener métricas de carga con cuatro clientes.
- [ ] 2. Ciudad: aumentar superficie transitable, calles y aceras, patios de
  tierra/pasto, varias casas accesibles, ruinas, vehículos y fuego del cliente.
  Compartir exactamente la geometría de colisión y los objetivos entre cliente
  y servidor. Verificar caminos hasta interiores y puntos de misión.
- [ ] 3. Personajes: mantener DANTE y reemplazar el otro aspecto por una operadora
  femenina reconocible; conservar identificadores de cuenta compatibles.
  Revisar lobby, dúo, escuadra, tercera persona y agarre de armas.
- [ ] 4. Integración: compilar scripts, ejecutar navegación real y partidas ENet,
  inspeccionar imágenes renderizadas y registrar resultados, límites y comandos
  de actualización. Publicar cada fase como checkpoint sin forzar historial.

## Hallazgos iniciales (todavía no son correcciones validadas)

- El mapa actual tiene un piso de 72 × 72 m y edificios sólidos sin puertas.
- HordeDirector crea zombis sin asignar objetivo. La IA sólo adquiere jugadores
  visibles a unos 20 m; varios puntos de aparición quedan fuera de ese alcance.
- La navegación consulta si terminó antes de solicitar su primer punto de ruta.
  Hay que probar movimiento real, no solamente transiciones de estado.
- El terreno ya omite sus mallas en headless; las escenas de actores todavía
  contienen cámaras, mallas, etiquetas y recursos visuales. No se atribuye el
  ping de 800 ms al renderizado sin medirlo.
- El lobby crea peticiones HTTPS para su indicador; incluye establecimiento de
  conexión. La partida tiene un ping ENet aparte. Ambos redondean <=25 ms a cero.
- El servidor no establece un límite explícito para su bucle de frames.

## Recuperación y reglas de publicación

Leer primero este archivo, luego CURRENT_STATUS.md y los commits de la rama.
Los cambios de la fase anterior ya están integrados en main y no deben repetirse.
Guardar checkpoints remotos después de cambios coherentes y antes de interrumpir.
No incluir cachés .godot, build, node_modules, importaciones generadas, credenciales
ni claves de firma. Conservar el gitlink vendor/Objetos3D en
`28ea7a10a18fbe05a91fb3d920678991fff4afef` y sus enlaces canónicos.

La copia local recuperada es un snapshot con ascendencia Git artificial. Publicar
mediante árboles/commits basados en el SHA remoto real; no hacer force-push ni
sobrescribir main. Una nueva integración se revisa en un PR separado del PR #1
ya cerrado. Las pruebas de Android físico y la latencia WAN real requieren los
dispositivos/VPS del propietario; no presentar pruebas locales como esas medidas.

## Registro de validación

Pendiente para estas nuevas fases. Godot local disponible: 4.6.3 estable.
La compilación y pruebas de presentación de beta.5 y el portal se validaron en
la fase anterior; no sustituyen las pruebas de esta ciudad y nueva simulación.

### Checkpoint 1 — persecución y separación de presentación

Implementado: escenas base sin recursos visuales; PlayerPresentation,
ZombiePresentation y AmmoPickupPresentation se cargan sólo con pantalla. La
puntería autoritativa usa Node3D, sin Camera3D. Cápsulas de zombis independientes.
Dedicado limitado a 60 frames/s, sin cambiar los 60 ticks de física. Registros
DEADFALL_SERVER_PERF cada diez segundos con intervalos de tick y costo/payload de
snapshots. El lobby distingue API de PARTIDA y no convierte 25 ms en cero.

La prueba reprodujo además el bloqueo principal: Recast devuelve puntos a y=0.5
m sobre el suelo, mientras path_desired_distance era 0.35 m. El agente nunca
avanzaba el primer punto y el movimiento XZ quedaba en cero. path_height_offset
corrige ese desfase. Las hordas ahora reciben una orden de persecución persistente.

Validación: gameplay_compile_smoke pasó. server_navigation_smoke pasó recorriendo
una ruta de 10 puntos alrededor de la clínica desde más de 29 m de distancia hasta
1.79 m del jugador; comprobó ausencia de nodos de presentación en actores/mapa y
que activar crawler no deforma otro zombi. El indicador HTTP está cambiando a
HTTPClient persistente con tiempo de conexión separado: pendiente prueba específica.
Pendientes: regresiones históricas adaptadas a escenas visuales separadas, prueba
ENet con cuatro clientes y mediciones. La nueva ciudad está en construcción y aún
no sustituye el mapa en este checkpoint.

### Checkpoint 2 — ciudad y operadora (2026-09-17)

La ciudad compartida por campaña/dúo/escuadra mide 192 × 192 m: calles de asfalto,
aceras, cruces, quince casas con puertas de 3 m, interiores y cubiertas parciales,
parque, vegetación, catorce autos destruidos y cuatro incendios del cliente.
CityLayout describe las colisiones; CityPresentation carga materiales, modelos,
vegetación, luces y humo exclusivamente en el cliente. Las hordas eligen puntos
seguros próximos a los jugadores para mantener presión en el mapa ampliado.

La nueva prueba de navegación pasó con 11 puntos de ruta y llegada a 1.79 m del
jugador. Se corrigió el paso de bordillos compartiendo CharacterMovement entre
predicción del cliente y autoridad: subir hasta 25 cm con comprobación de techo,
obstáculo y apoyo. No se permite atravesar paredes ni vehículos.

VALERIA sustituye el aspecto anterior de operator_01 con cuerpo ajustado sobre la
base ponderada de J-Toastie, rostro, cabello recogido y equipo de comunicación
originales. DANTE conserva su diseño. El ID de cuenta no cambia. Ambos pasaron la
prueba renderizada de agarre para rifle, pistola y machete. Se corrigió la altura
al arrastrarse para la nueva base. La atribución de la base debe mantenerse.

El sondeo de lobby usa HTTPClient persistente: la prueba real HTTP/1.1 confirmó
reutilización de conexión, rechazo de una respuesta de salud inválida y que 25 ms
se muestran como 25. La conexión TLS/DNS se informa aparte del tiempo de petición.
Las partidas siguen midiendo ENet; una partida sin respuesta no usa el ping HTTP
como sustituto.

Validaciones históricas iniciales: combate, IA/daño, hordas, red, escuadra,
campaña, hardening, Phase 11, Android template, instalador y partidas reales de
2/4 participantes pasaron. Tres pruebas de presentación/escenas requirieron
adaptación por separar los recursos visuales y ajustar la nueva operadora; deben
repetirse antes de cerrar. Pendiente la medición nueva de carga con 4 clientes,
revisión final de capturas, compatibilidad de contenido/versión y gates finales.

Archivos clave nuevos: src/maps/campaign/City*.gd y shaders,
src/assets/FemaleOperatorDesign.gd, src/core/CharacterMovement.gd,
scripts/ci/server_navigation_smoke.gd, control_latency_smoke.py,
match_load_smoke.py, city_visual_smoke.gd y operators_visual_smoke.gd.
