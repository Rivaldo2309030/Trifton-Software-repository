# Resumen Consolidado de Cambios y Tareas (Hasta 22/10/2025)

Este documento consolida el progreso del proyecto, las funcionalidades implementadas, los desafíos superados y las tareas pendientes, incluyendo una explicación detallada sobre el KPI de "Clientes" en el dashboard.

---

## 1. Estado General del Proyecto

Hemos desarrollado una aplicación Flutter robusta para la gestión de logística, abarcando embarques, notas de venta, pagos y sincronización. La aplicación se ha adaptado a una nueva estructura de base de datos, se ha mejorado su resiliencia ante la falta de conectividad y se han implementado funcionalidades críticas para la operación en campo.

---

## 2. Funcionalidades Clave Implementadas

### a. Gestión de Usuarios y Autenticación
*   **Refactorización Vendedor a Usuario:** Eliminación del concepto de `Vendedor` y reemplazo por `Usuario` en todo el flujo de embarques y base de datos.
*   **Login y Registro:** Implementación de un flujo completo de login (online y offline) y registro de usuarios.
*   **Credenciales Offline:** Guardado seguro de credenciales hasheadas en SQLite para login sin conexión.
*   **Interfaz de Usuario:** Visualización del nombre de usuario activo en la UI ("Hola, [Nombre de Usuario]").

### b. Módulo de Embarques
*   **Creación y Consulta:** Funcionalidad completa para crear nuevos embarques y consultar un historial de embarques existentes, con filtros por fecha.
*   **Edición y Cancelación:** Implementación de la capacidad para editar y cancelar embarques ya creados.
*   **Carga Dinámica de Catálogos:** Todos los catálogos (productos, clientes, almacenistas, almacenes, etc.) se cargan dinámicamente desde la base de datos a través de APIs.
*   **Lógica de Precios Dinámicos:** Cálculo de precios unitarios basado en la combinación `idcliente`, `idproducto` e `idunidad` a través de `api_precios.php`.
*   **Estatus por Producto:** Gestión del estatus individual de cada producto dentro de un embarque (`embarque_detalle`), con `idestatus = 1` ('EE') por defecto.
*   **Guardado Híbrido:** Capacidad de guardar embarques directamente en el servidor o localmente en SQLite si no hay conexión.
*   **Sincronización Offline:** Verificación exitosa de la sincronización de embarques guardados localmente al servidor una vez que se recupera la conexión.

### c. Módulo de Notas de Venta y Pagos
*   **Generación de Notas:** Creación de notas de venta a partir de embarques, con cálculo automático de `fechapago` basado en `diaspago` del cliente.
*   **Consulta de Notas:** Pantalla de "Pedidos" rediseñada para mostrar primero clientes con deudas y luego sus notas pendientes. Incluye una pestaña de "Historial" para ver todas las notas (pagadas y pendientes).
*   **Detalle de Nota y Pagos:** Pantalla de detalle de nota que muestra productos, permite registrar pagos (monto y tipo de pago) y oculta el formulario de pago si la nota está saldada.
*   **Recálculo de Nota:** Recálculo automático del total y saldo de la nota basado en los productos con estatus 'SP' (Salida por Pedido) en `embarque_detalle`.
*   **Impresión de Tickets:** Generación de una vista de ticket (`ticket_screen.dart`) para cualquier nota.

### d. Mejoras de Robustez y Experiencia de Usuario
*   **Centralización de Endpoints:** Creación de `lib/services/api_config.dart` para centralizar la URL base de las APIs.
*   **Manejo de Conectividad:** Implementación de verificaciones de conectividad en pantallas clave (`PedidosScreen`, `NotaDetailScreen`, `SyncScreen`) para mostrar mensajes amigables en lugar de errores técnicos.
*   **Depuración Extensa:** Resolución de numerosos errores de compilación, lógica de negocio y problemas de servidor (ej. caché de OPcache, discrepancias en nombres de tablas/columnas).
*   **Dashboard Funcional:** Implementación de `api_dashboard_data.php` y actualización de `DashboardScreen` para mostrar datos dinámicos (pedidos, embarques, clientes) y tendencias diarias.

---

## 3. Tareas Pendientes

El backlog actual de tareas, en orden de prioridad, es:

1.  **Corregir la Zona Horaria:** Implementar la lógica para que todos los registros de fecha y hora se guarden utilizando la hora del dispositivo local en lugar de la hora del servidor. Esto es crucial para la consistencia de los datos.
2.  **Mejorar el Historial de Pedidos:** Darle mayor funcionalidad a la pestaña "Historial" en la pantalla de Pedidos, añadiendo filtros avanzados y posibles acciones al seleccionar ítems.
3.  **Implementar "Imprimir Embarque":** Crear una vista de impresión/ticket para los embarques, de forma similar a la que ya existe para las notas de venta.

---

## 4. Explicación del KPI "Clientes" en el Dashboard

### Problema
El KPI de "Clientes" en el dashboard principal actualmente muestra `0`, a pesar de que existen clientes registrados en la base de datos.

### Causa
La API `api_dashboard_data.php` fue diseñada para contar **nuevos clientes registrados en el día actual o el día anterior**. La consulta SQL utilizada es:

```sql
SELECT COUNT(*) AS count FROM clientes WHERE DATE(regtimestamp) = ? AND estado = 1
```

Al revisar los datos de tu base de datos, se encontró que el cliente existente (`Tienda La Preferida`) tiene un `regtimestamp` de `'2025-10-10 18:33:32'`. Dado que la fecha actual es 22 de octubre de 2025, este cliente no cumple con el criterio de haber sido registrado hoy o ayer. Por lo tanto, la API devuelve `0` para el conteo de "nuevos clientes" en los últimos dos días, lo cual es correcto según su lógica actual.

### Solución (si se desea cambiar el comportamiento)
Si la intención es que el KPI de "Clientes" muestre el **número total de clientes activos** en la base de datos (independientemente de su fecha de registro), la consulta en `api_dashboard_data.php` debería modificarse para eliminar el filtro por fecha. La consulta sería:

```sql
SELECT COUNT(*) AS count FROM clientes WHERE estado = 1
```

Esta modificación haría que el dashboard refleje el total de clientes activos en tu sistema. Si se mantiene la lógica actual, el KPI solo mostrará un valor diferente de cero cuando se registre un nuevo cliente en el día actual o el día anterior.

---

Este resumen servirá como nuestra fuente de verdad para el estado del proyecto. ¡Estamos listos para continuar con la siguiente tarea!