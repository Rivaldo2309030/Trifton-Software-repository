# Resumen de Cambios y Tareas Pendientes (Sesión del 30/09/2025)

Este documento resume las modificaciones realizadas en el proyecto y las tareas que quedan por hacer.

---

## 1. Módulo de Embarques (Completado)

Se realizaron cambios significativos en este módulo para alinearlo con los nuevos requisitos de la junta.

### Tareas Realizadas:

*   **Refactorización del Formulario de Creación:**
    *   Se añadieron nuevos campos al formulario para ser rellenados por el usuario: `Camión (Chofer)`, `Tipo de Movimiento` y `Motivo de Cancelación`.
    *   Se eliminaron los campos `Estatus`, `Estado del Proceso` y `Fecha Salida` de la interfaz de creación, ya que se determinó que su valor debe ser gestionado automáticamente por el sistema.

*   **Nueva Selección de Productos:**
    *   Se eliminó la entrada manual de nombre y precio de producto para reducir errores.
    *   Se implementó un menú desplegable para seleccionar productos de una lista predefinida (actualmente con datos de ejemplo).

*   **Lógica de Precios Dinámicos (Ejemplo):**
    *   Se implementó una función de **ejemplo** en la app que ajusta el precio del producto basado en el cliente y almacén seleccionados. Esto sirve como base para la futura lógica de negocio.

*   **Actualizaciones en el Backend (API):**
    *   Se modificó `api_embarques.php` para aceptar los nuevos campos manuales.
    *   La API ahora guarda automáticamente el valor `'Activo'` en el campo `estado_proceso` al crear un nuevo embarque.
    *   Se preparó la API para los nuevos campos de control en la base de datos: `reg_timestamp` (para la fecha de creación) y `estado_registro` (para borrado lógico).

*   **Depuración y Corrección de Base de Datos:**
    *   Se diagnosticaron y solucionaron errores `500 (Internal Server Error)` que ocurrían al guardar.
    *   Se identificó que los errores se debían a que la estructura de las tablas en la base de datos no coincidía con los datos que el nuevo código PHP intentaba guardar.
    *   Se proveyeron los comandos SQL (`ALTER TABLE` e `INSERT`) para actualizar las tablas `embarques` y `productos` y hacerlas compatibles con el nuevo código.

---

## 2. Tareas Pendientes

*   ### Módulo de Embarques:
    *   **Implementar Lógica de Precios Real:** Reemplazar la función de ejemplo para precios dinámicos con las reglas de negocio definitivas. El lugar está marcado con un comentario `// TODO` en `lib/screens/embarque_screen.dart`.
    *   **Resolver Asunto de Zona Horaria:** La hora de registro se guarda con la hora del servidor (UTC). El intento de ajuste a 'America/Merida' causó un error y fue revertido por petición. Queda pendiente investigar la configuración del servidor o un método alternativo.
    *   **Cargar Catálogos Faltantes:** Las listas de 'Clientes' y 'Almacenistas' siguen siendo datos de ejemplo en la app. Deben ser cargadas desde sus respectivas APIs.

*   ### Módulo de Pedidos:
    *   **Conexión con Backend:** Esta es la siguiente gran tarea. La interfaz de usuario existe pero no se comunica con el servidor. Se debe implementar la lógica para obtener y guardar pedidos a través de la API correspondiente.
    *   **Implementar Funcionalidades Específicas:** Quedo a la espera de las instrucciones detalladas que mencionaste para este módulo.