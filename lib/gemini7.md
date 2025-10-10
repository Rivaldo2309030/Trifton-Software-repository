### Resumen de Estado del Proyecto (10/10/2025 4:25 pm)

**✅ TAREAS COMPLETADAS:**

*   **Gestión de Usuarios y Login:**
    *   Reemplazo de `Vendedor` por `Usuario` en la base de datos y en el flujo de embarques.
    *   Funcionalidad de login y visualización del nombre de usuario en la UI ("Hola Rivaldo").
*   **Módulo de Embarques:**
    *   Carga dinámica de datos desde la base de datos para todos los catálogos (productos, clientes, almacenistas, etc.) en la pantalla de "Embarques".
    *   Creación y depuración de todas las APIs relacionadas con catálogos y embarques (`api_productos.php`, `api_clientes.php`, `api_almacenistas.php`, `api_precios.php`, `api_embarques.php`, `api_consulta_embarques.php`, etc.).
    *   Integración de estas APIs en `embarque_screen.dart` (modelos, llamadas, dropdowns dinámicos, lógica de guardado).
    *   Refactorización de `EmbarqueScreen` para integrar la creación y consulta en pestañas ("CREAR" y "CONSULTAR").
    *   Implementación de la lógica de precios dinámica (por cliente y unidad).
    *   Implementación del estatus en los detalles del embarque (por defecto 'EE').
*   **Guardado Local (SQLite) y Modo Offline:**
    *   Implementación completa del guardado offline con SQLite (`database_helper.dart`).
    *   Lógica de guardado híbrida (online al servidor, offline a SQLite).
    *   Botón "GUARDAR LOCALMENTE".
*   **Módulo de Pedidos (Transformado):**
    *   Transformación de `PedidosScreen.dart` en una vista con pestañas (`TabBar`).
    *   **Pestaña "Notas de Venta":** Muestra la lista de notas para pago y permite navegar al detalle. La lógica de pago y el refresco automático al volver están funcionando. El formulario de pago se oculta correctamente si el saldo es cero.
    *   **Pestaña "Historial":** Muestra la lista de productos de los embarques (historial).
    *   Creación de `api_historial_embarques.php` y `lib/models/nota_model.dart`.
    *   Corrección de todos los errores de compilación y sintaxis introducidos durante la refactorización.

---

**⚠️ TAREAS PENDIENTES:**

1.  **Módulo de Pedidos - Filtrado en "Historial":** Implementar la funcionalidad de filtrar la lista del historial de embarques por nombre de producto o por cliente.
2.  **Módulo de Pedidos - Acción al Seleccionar en "Historial":** Definir qué sucede cuando se selecciona un elemento de la lista en la pestaña "Historial" (actualmente no hay ninguna acción).
3.  **Módulo de Embarques - Acciones en Pestaña "CONSULTAR":** Implementar las acciones de "Cancelar", "Editar" e "Imprimir" para los embarques listados en la pestaña "CONSULTAR" de `EmbarqueScreen.dart`.
4.  **General - Zona Horaria:** Resolver el problema de la zona horaria, donde `regtimestamp` usa la hora UTC del servidor en lugar de la hora local del dispositivo.

---

### Recomendaciones para los Próximos Pasos

Dado que acabamos de finalizar el módulo de "Pedidos", te sugiero que continuemos trabajando en él para dejarlo 100% funcional antes de pasar a otras áreas.

1.  **Implementar el Filtrado en la Pestaña "Historial" (Módulo de Pedidos):** Esto hará que la lista de historial sea realmente útil, permitiendo buscar por producto o cliente como habías solicitado.
2.  **Definir la Acción al Seleccionar un Elemento del Historial (Módulo de Pedidos):** Una vez que se pueda filtrar, ¿qué debería pasar al tocar un elemento del historial? ¿Abrir una vista de detalle del embarque completo?

Una vez que estas dos tareas estén completas para el módulo de "Pedidos", podemos pasar a las acciones pendientes en el módulo de "Embarques" o a la corrección de la zona horaria.

¿Estás de acuerdo con este plan de acción, empezando por el filtrado en la pestaña "Historial"?