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
