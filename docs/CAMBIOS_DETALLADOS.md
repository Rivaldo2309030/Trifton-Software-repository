# CAMBIOS DETALLADOS — Aplicación móvil de Cruz 🛠️

 # CAMBIOS DETALLADOS — Aplicación móvil de Cruz (Definitivo) 🛠️

 **Versión:** Definitiva  | **Fecha:** 16/12/2025

 ---

 ## 📋 Resumen ejecutivo
 Documento final de especificación técnica para el equipo de desarrollo. Incluye: cambios de base de datos (migraciones), reglas de negocio (precio, tipos), modificaciones en UI (Embarques y Pedidos), y reglas de impresión (tickets para Productos/Cajas). Además añade recomendaciones de rendimiento, pruebas y consideraciones offline/zonas horarias.

 ---

 ## 1. BASE DE DATOS (MIGRACIONES) — cambios definitivos

 ### A. Nuevos Campos y Tablas

 1. **Tabla `embarque`**
    - Agregar columna `tipo_venta` TINYINT(1) NOT NULL DEFAULT 1 — 0 = Contado, 1 = Crédito.

 2. **Tabla `embarque_detalle`**
    - Agregar columna `tipo_producto` CHAR(1) NOT NULL DEFAULT 'P' — 'P' = Producto (monetario), 'C' = Caja (envase).
    - **Propagación:** Al generar la nota desde un embarque, copiar `tipo_producto` a `nota_detalle` (fuente de verdad: `embarque_detalle`).

    **Nota de migración:** Se ha añadido también la columna `tipo_venta` al caché de consultas `embarques_consulta` (migración v14). La aplicación incrementa la versión de la DB a **14** y ejecuta un ALTER TABLE para añadir `tipo_venta` en DBs existentes; además hay una comprobación en `onOpen` que asegura la columna incluso si la migración no se ejecutó correctamente.

 3. **Tabla `tipos_pago`**
    - Insertar un método de pago: `CAJA` (para devoluciones de envase). Mantener casing consistente (recomendado: `CAJA`).

 ### B. Datos obligatorios y validaciones
 - **Cliente "MOSTRADOR" (id = 0):** insertar un cliente con `idcliente = 0` (nombre: 'MOSTRADOR') si no existe. Añadir una validación y test que lo consulte explícitamente (evitar que ORMs lo ignore por `0`).
 - **Índices sugeridos:** añadir índices en columnas claves para filtros y orden: `notas(idcliente, saldo)`, `embarque(tipo_venta)`, `embarque_detalle(tipo_producto)`, `notas(regtimestamp)`.

 ---

 ## 2. PANTALLA: EMBARQUES (Creación de pedidos)

 ### A. Interfaz de Usuario (UI)
 - **Selector Cliente:** Al elegir cliente, mostrar dropdown para seleccionar **Crédito / Contado** (persistir en `embarque.tipo_venta`).
 - **Selector Producto por línea:** Además del producto/unidad, añadir dropdown **Tipo**: `P` | `C`.

 ### B. Lógica de Precios (Fallback)
 1. Intentar obtener precio para `(idcliente_actual, idproducto, idunidad)`.
 2. Si no existe, usar precio para `(idcliente = 0, idproducto, idunidad)` (cliente MOSTRADOR).
 3. Cargar ese precio y mostrar en UI.

 ---

 ## 3. PANTALLA: PEDIDOS Y SALDOS (Visualización)

 La pantalla tendrá **dos pestañas**: **PRODUCTOS** y **CAJAS**.

 ### 🔴 Pestaña 1: PRODUCTOS (Gestión financiera)
 - **Filtro de fecha:** Por defecto la fecha estará VACÍA (NULL). Se cargarán todas las notas con saldo pendiente (históricas y actuales). Si el usuario selecciona una fecha, se aplica el filtro.
 - **Encabezado (Resumen):** `Saldo Anterior`, `Pedido de Hoy`, `Total Crédito` (Saldo Anterior + Pedido de Hoy).
 - **Listado:** Muestra notas con `tipo_producto = 'P'`.

 ### 📦 Pestaña 2: CAJAS (Gestión de envases)
 - **Encabezado (Resumen):** `Cajas Pendientes por Devolver`, `Cajas en Entregas (Hoy)`, `Total de Cajas Entregadas`.
 - **Listado:** Muestra notas con `tipo_producto = 'C'`.
 - **Orden:** Primero notas con deudas antiguas (por `fechapago`/saldo), luego entregas/datos del día.

 ---

 ## 4. MÓDULO DE PAGOS / ABONOS — reglas

 **Comportamiento por tipo de pago**:

 - **Pago monetario (Efectivo/Transferencia/Por defecto):**
   - Input: `Monto` (moneda). Resta deuda financiera.

 - **Pago con `CAJA` (Devolución de envase):**
   - Input: `Cajas a devolver` (entero). Visualmente renombrar el campo a "Cajas a devolver".
   - Lógica: Resta deuda de envases (cantidad), calcula crédito monetario: `cantidad * precio_unitario_de_la_caja` (precio tomado desde el embarque/nota o precios por cliente). Registrar pago en `pagos_m` con `tipopago = 'CAJA'` y guardar la cantidad devuelta vinculada a `iddetalle_embarque` cuando aplique.

 ---

 ## 5. REGLAS DE IMPRESIÓN (TICKETS) 🖨️

 El sistema decidirá formato y número de copias según `tipo_producto` y contenido de la transacción.

 - **Productos ('P'):** imprimir **3** tickets (Original + 2 copias). Formato estándar con montos en pesos.
 - **Cajas ('C'):** imprimir **2** tickets (no se imprime la copia #1 adicional). Encabezados:
   - Si es entrega: **"CAJAS ENTREGADAS"**
   - Si es devolución: **"DEVOLUCIÓN DE CAJAS"**
 - **Etiquetas dinámicas (para cajas):**
   - `Cantidad Pagada` → **"Cajas entregadas"**
   - `Saldo Anterior` → **"Cajas que falta devolver"**
   - `Saldo Actual` → **"Cajas que le quedan por devolver"**

 **Nota sobre reimpresiones:** Cuando se reimprime una nota ya saldada, el sistema debe usar el formato del **último pago registrado** (por ejemplo, si el último pago fue con `CAJA`, reimprimir en formato de devolución/entrega de cajas).

 ---

 ## 6. API / BACKEND — cambios y endpoints

 - `api_embarques.php`:
   - Aceptar y persistir `tipo_venta` en `embarque` y `tipo_producto` en `embarque_detalle`.
 - `api_precios.php` / lógica de precios:
   - Buscar precio por `(idcliente, idproducto, idunidad)` → fallback a cliente 0.
 - `api_generar_nota.php`:
   - Propagar `tipo_producto` a `nota_detalle` al generar la nota.
 - `api_registrar_pago.php`:
   - Soportar `tipopago = 'CAJA'` (recibir cantidad de cajas, calcular crédito monetario y guardar vínculo con `iddetalle_embarque`).
 - `api_consulta_notas_v2.php` / Pedidos:
   - Retornar datos para el bloque resumen (saldo anterior, pedido de hoy, total crédito) y permitir filtrar por `tipo_producto`.
 - `api_cajas_resumen.php` (nuevo):
   - Devolver por cliente: `pendientes`, `en_entregas_hoy`, `total_entregadas`.

 ---

 ## 7. ZONA HORARIA, OFFLINE Y SINCRONIZACIÓN

 - **Definición de "Hoy":** usar la fecha local del dispositivo para cálculos de "Pedido de Hoy". En la API, aceptar fechas explícitas en UTC o con offset y almacenar timestamps en UTC para consistencia.
 - **Offline:** garantizar que el fallback de precio (cliente 0) y los pagos `CAJA` funcionen en modo offline; al sincronizar, validar idempotencia y confirmar que la cantidad y el crédito monetario se aplicaron correctamente.

 ---

 ## 8. INDICES, PERFORMANCE Y PRÁCTICAS

 - Añadir índices en columnas críticas: `notas(idcliente, saldo)`, `embarque(tipo_venta)`, `embarque_detalle(tipo_producto)`, `notas(regtimestamp)`, `pagos_m(idnota, regtimestamp)`.
 - Implementar paginación en APIs de listados (Pedidos) para evitar cargas excesivas en producción.

 ---

 ## 9. CASOS DE PRUEBA / CRITERIOS DE ACEPTACIÓN

 1. Cliente MOSTRADOR (`id=0`) existe; su precio se usa como fallback si no hay precio por cliente.
 2. Seleccionar Contado/Crédito persiste correctamente `tipo_venta`.
 3. Guardar línea `tipo_producto='C'` se refleja en `embarque_detalle` y al generar nota en `nota_detalle`.
 4. Pestañas Productos/Cajas muestran datos filtrados y resumen por cliente correcto.
 5. Pago con `CAJA` resta unidades de cajas y registra pago con cálculo monetario correcto.
 6. Tickets imprimen 3 copias para productos y 2 para cajas, con encabezados y etiquetas dinámicas correctas.

 ---

 ## 10. PLAN DE TRABAJO (PRs y tareas)

 1. **PR1 — Migraciones y datos base:** crear cliente 0, agregar `tipo_venta`, `tipo_producto`, insertar `CAJA` en `tipos_pago`, añadir índices.
 2. **PR2 — Lógica precios:** fallback a cliente 0 en API y en app (offline aware).
 3. **PR3 — Embarques UI:** combos y guardado (`tipo_venta`, `tipo_producto`) + tests.
 4. **PR4 — Notas y pagos:** propagar `tipo_producto` a `nota_detalle`, `api_registrar_pago.php` soporte `CAJA`.
 5. **PR5 — Pedidos UI:** pestañas Productos/Cajas y bloque resumen por cliente; paginación.
 6. **PR6 — Impresión/Reportes:** tickets de cajas y reimpresión según último pago.
 7. **PR7 — QA & Release:** pruebas de integración (offline + sync), correcciones y despliegue en staging.

 