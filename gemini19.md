# Resumen de Sesión y Guía de Precios (gemini19.md)

## 1. Resumen General de la Sesión

*   **Objetivo:** Investigar y solucionar por qué el precio de respaldo ("precio público") no se aplicaba automáticamente en la pantalla de "Embarques" cuando un producto no tenía un precio específico asignado a un cliente.

*   **Proceso de Diagnóstico:**
    1.  Se validó que el código de la API `api_precios.php` contenía la lógica correcta para buscar un precio de respaldo.
    2.  Mediante consultas SQL directas a la base de datos, se descubrió que no existían precios registrados para el producto de prueba.
    3.  Al intentar insertar los precios, un error de `FOREIGN KEY` reveló que el "Cliente 0" que se creía que existía, en realidad no estaba presente en la tabla `clientes`.
    4.  Un análisis final de la estructura de la tabla (`SHOW CREATE TABLE`) demostró que la columna `idcliente` es `AUTO_INCREMENT`, lo que impide forzar la creación de un cliente con un ID manual de `0`.

*   **Solución Implementada:**
    Se optó por la solución más segura para no alterar la estructura de la base de datos. Se creó un cliente "MOSTRADOR" dejando que la base de datos le asignara un ID (el `91`), y se adaptó la lógica de la aplicación para usar este ID como referencia para el precio público.

*   **Resultado:** Se solucionó el problema de raíz, confirmando que la lógica de la aplicación es correcta y que el fallo se debía a la configuración de los datos y la estructura de la BD. La funcionalidad de precios de respaldo ahora es 100% operativa.

---

## 2. Guía para Administrar Precios en la Base de Datos

Esta guía explica el funcionamiento del sistema de precios para que el equipo de ingeniería o administración pueda gestionarlos correctamente.

### Concepto Clave: Dos Tipos de Precios

El sistema maneja dos niveles de precios, ambos gestionados en la tabla `precios`:

1.  **Precio Específico por Cliente:** Es un precio especial que solo aplica a un cliente en particular.
2.  **Precio Público (de Respaldo):** Es el precio "general" que se aplica a cualquier cliente que no tenga un precio específico para un producto. Este precio está asociado al cliente **"MOSTRADOR" (ID 91)**.

### Flujo Lógico de la API (`api_precios.php`)

Cuando la aplicación solicita un precio, la API sigue estas reglas en orden:
1.  Busca un **Precio Específico** que coincida con el `idcliente`, `idproducto` y `idunidad`.
2.  Si lo encuentra, devuelve ese precio.
3.  Si **NO** lo encuentra, busca un **Precio Público**, usando el `idcliente = 91` para el mismo producto y unidad.
4.  Si lo encuentra, devuelve el precio público.
5.  Si tampoco lo encuentra (porque no se ha configurado), devuelve un valor nulo, lo que causa que la app muestre `0.0`.

### Cómo Realizar Tareas Administrativas (Comandos SQL)

#### A. Añadir un Precio Público a un Producto
Para que un producto tenga su precio de respaldo, se debe insertar una fila en la tabla `precios` usando `91` como `idcliente`.

**Plantilla:**
```sql
-- Plantilla para agregar un nuevo PRECIO PÚBLICO
INSERT INTO precios (idproducto, idunidad, idcliente, preciounitario, estado)
VALUES ([ID_DEL_PRODUCTO], [ID_DE_LA_UNIDAD], 91, [PRECIO_A_ASIGNAR], 1);
```
**Ejemplo:**
```sql
-- Asigna un precio público de $165.00 al "PLÁTANO ROATAN" (ID 27) por "CAJA" (ID 1)
INSERT INTO precios (idproducto, idunidad, idcliente, preciounitario, estado)
VALUES (27, 1, 91, 165.00, 1);
```

#### B. Añadir un Precio Específico a un Cliente
El proceso es idéntico, pero en lugar de usar `91`, se usa el `idcliente` del cliente al que se le quiere dar el trato especial.

**Plantilla:**
```sql
-- Plantilla para agregar un PRECIO ESPECIAL A UN CLIENTE
INSERT INTO precios (idproducto, idunidad, idcliente, preciounitario, estado)
VALUES ([ID_DEL_PRODUCTO], [ID_DE_LA_UNIDAD], [ID_DEL_CLIENTE_ESPECIFICO], [PRECIO_ESPECIAL], 1);
```
**Ejemplo:**
```sql
-- Asigna un precio especial de $180.00 al cliente "DON LAURO" (ID ej: 15) para el plátano por caja.
INSERT INTO precios (idproducto, idunidad, idcliente, preciounitario, estado)
VALUES (27, 1, 15, 180.00, 1);
```
