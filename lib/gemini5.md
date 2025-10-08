# Resumen de Cambios y Tareas (Sesión del 08/10/2025 v2)

Este documento resume los cambios realizados para adaptar la app al nuevo esquema de la base de datos (reemplazando Vendedor por Usuario) y la implementación de la funcionalidad de guardado local (offline) con SQLite.

---

## 1. Tareas Completadas

### a. Fase 0: Desbloqueo de Colaboradores

*   Se creó una nueva rama `RivaldoRama`.
*   Se hizo commit y se subieron todos los cambios funcionales de la sesión anterior para que otros desarrolladores (Lizbeth) pudieran comenzar a trabajar en el módulo de login.

### b. Fase 1: Refactorización de `Vendedor` a `Usuario`

El objetivo fue eliminar por completo el concepto de `Vendedor` y reemplazarlo por `Usuario` en todo el flujo de "Embarques".

*   **Backend (APIs PHP):**
    *   `api_embarques.php`: Modificada para que el `INSERT` en la tabla `embarque` utilice `idusuario` en lugar de `idvendedor`.
    *   `api_consulta_embarques.php`: Reescrita para hacer `JOIN` con la tabla `usuarios` (en vez de `vendedores`) y devolver el `nombreusuario`.
*   **Frontend (Flutter - `embarque_screen.dart`):**
    *   Se eliminó el modelo de datos `Vendedor`.
    *   Se quitó el dropdown de "Vendedor" de la interfaz de usuario.
    *   Se eliminó toda la lógica asociada (variables de estado, llamadas a API).
    *   Se actualizó la función de guardado para enviar un `idusuario` (actualmente fijo en `1` como placeholder).
    *   Se actualizó la pestaña "CONSULTAR" para mostrar la columna "Usuario".

### c. Fase 2: Implementación de Guardado Offline con SQLite

Se implementó la capacidad de la aplicación para guardar embarques localmente si no hay conexión a internet.

*   **Dependencias**: Se añadieron los paquetes `sqflite` y `path_provider` al `pubspec.yaml`.
*   **Database Helper**: Se creó el archivo `lib/services/database_helper.dart`, que contiene la clase `DatabaseHelper` para gestionar la base de datos SQLite local.
    *   Define la estructura de las tablas locales `embarque` y `embarque_detalle`.
    *   Incluye un campo `synced` para rastrear qué registros se han subido al servidor.
    *   Proporciona un método `insertEmbarque` transaccional para guardar un embarque y sus detalles de forma segura.
*   **Lógica de Guardado Híbrida**: Se refactorizó la lógica de los botones en `embarque_screen.dart`:
    *   El botón **GUARDAR** ahora intenta conectarse al servidor. Si detecta un error de red (o cualquier otro error durante el POST), automáticamente guarda los datos en la base de datos SQLite local.
    *   El botón **GUARDAR LOCALMENTE** ahora guarda el embarque directamente en la base de datos SQLite sin intentar una conexión al servidor.

---

## 2. Tareas Pendientes

1.  **Probar la Funcionalidad de SQLite**: El siguiente paso inmediato es verificar que el guardado local y el fallback funcionen como se espera.
2.  **Implementar Sincronización**: Crear la lógica para que, al iniciar la aplicación o al recuperar la conexión, los embarques guardados localmente (`synced = 0`) se envíen al servidor.
3.  **Fase 3: Reconstruir Módulo "Pedidos"**: Pausado. El objetivo es reescribir `PedidosScreen.dart` para que funcione como un historial de ventas, consultando los datos de `embarque_detalle` desde una nueva API (`api_consulta_pedidos.php`).
4.  **Implementar Acciones en Consulta de Embarques**: Dar funcionalidad a los botones de **Cancelar, Editar e Imprimir** en la pestaña "CONSULTAR".
5.  **Resolver Asunto de Zona Horaria**: La hora de registro sigue usando la del servidor (UTC) en lugar de la local.

---

## 3. Estructura de Base de Datos (Fuente de Verdad)

Esta es la colección de scripts `CREATE TABLE` que usaremos como referencia única para todo el desarrollo futuro.

```sql
-- Usuarios (Tabla necesaria para el login y FK en embarque)
CREATE TABLE usuarios (
  idusuario INT PRIMARY KEY AUTO_INCREMENT,
  nombre VARCHAR(120) NOT NULL,
  password VARCHAR(255) NOT NULL, -- Hasheada
  regtimestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado INT DEFAULT 1 NOT NULL
);

-- Bitácora de cambios de estatus de un embarque
CREATE TABLE movimientos (
  idmovimiento INT PRIMARY KEY AUTO_INCREMENT ,
  idusuario INT NOT NULL,
  idembarquedetalle INT NOT NULL,
  regtimestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado INT DEFAULT 1 NOT NULL,
  FOREIGN KEY (idusuario) REFERENCES usuarios (idusuario),
  FOREIGN KEY (idembarquedetalle) REFERENCES embarque_detalle (iddetalle)
);

-- Creacion de notas
CREATE TABLE notas (
  idnota INT PRIMARY KEY AUTO_INCREMENT,
  idusuario INT NOT NULL,
  idcliente  INT NOT NULL,
  idalmacen  INT  NOT NULL,
  idembarque INT NOT NULL,
  total DECIMAL(14,2) NOT NULL DEFAULT 0.00,
  saldo DECIMAL(14,2) NOT NULL DEFAULT 0.00,
  pagos INT  NOT NULL DEFAULT 0,
  credito_dias INT NOT NULL DEFAULT 0,
  fechapago   DATETIME NOT NULL,
  envio BOOLEAN NOT NULL DEFAULT FALSE,
  regtimestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado INT DEFAULT 1 NOT NULL,
  
   FOREIGN KEY (idusuario) REFERENCES usuarios (idusuario),
   FOREIGN KEY (idcliente) REFERENCES clientes (idcliente),
   FOREIGN KEY (idalmacen) REFERENCES almacenes (idalmacen),
   FOREIGN KEY (idembarque) REFERENCES embarque (idfolioembarque)
);

-- Detalle de notas
CREATE TABLE nota_detalle (
  id INT PRIMARY KEY AUTO_INCREMENT,
  idnota INT NOT NULL,
  idproducto  INT NOT NULL,
  idunidad   INT NOT NULL,
  precio DECIMAL(14,2) NOT NULL DEFAULT 0.00,
  total DECIMAL(14,2) NOT NULL DEFAULT 0.00,
  regtimestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado INT DEFAULT 1 NOT NULL,
   
   FOREIGN KEY (idnota) REFERENCES notas (idnota),
   FOREIGN KEY (idproducto) REFERENCES productos (idproducto),
   FOREIGN KEY (idunidad) REFERENCES unidades (idunidad)
);

-- Pagos registrados a la nota
CREATE TABLE pagos_m (
  id INT PRIMARY KEY AUTO_INCREMENT,
  idnota INT NOT NULL,
  totalpago DECIMAL(14,2) NOT NULL,
  tipopago ENUM('Efectivo','Transferencia') NOT NULL,
  saldonota DECIMAL(14,2) NOT NULL,
  regtimestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado INT DEFAULT 1 NOT NULL,
  
   FOREIGN KEY (idnota) REFERENCES notas (idnota)
);

-- Cobros es independiente al cobrar al cliente
CREATE TABLE cobros (
  id INT PRIMARY KEY AUTO_INCREMENT,
  idnota  INT NOT NULL,
  total     DECIMAL(14,2) NOT NULL,
  tipocobro ENUM('Efectivo','Transferencia') NOT NULL,
  regtimestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado INT DEFAULT 1 NOT NULL,

   FOREIGN KEY (idnota) REFERENCES notas (idnota)
) ;

-- Almacenes
CREATE TABLE almacenes (
  idalmacen INT PRIMARY KEY AUTO_INCREMENT,
  nombrealmacen VARCHAR(50) NOT NULL,
  ubicacion VARCHAR(120),
  telefono VARCHAR(20),
  regtimestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado INT DEFAULT 1 NOT NULL
);

-- Almacenistas (Confirmado plural)
CREATE TABLE almacenistas (
  idalmacenista INT PRIMARY KEY AUTO_INCREMENT,
  nombre VARCHAR(120) NOT NULL,
  telefono VARCHAR(20),
  regtimestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado INT DEFAULT 1 NOT NULL
) ;

-- Ruta
CREATE TABLE ruta (
  idruta INT PRIMARY KEY AUTO_INCREMENT,
  nombreruta  VARCHAR(50) NOT NULL,
  responsable  VARCHAR(120) NOT NULL,
  regtimestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado INT DEFAULT 1 NOT NULL
);

-- Clientes (Confirmado sin guion bajo)
CREATE TABLE clientes (
  idcliente INT PRIMARY KEY AUTO_INCREMENT,
  idruta        INT NOT NULL,
  nombrecliente VARCHAR(150) NOT NULL,
  direccion      VARCHAR(250),
  telefono       VARCHAR(20),
  limitepago DECIMAL(14,2) NOT NULL DEFAULT 0.00,
  diaspago INT NOT NULL DEFAULT 0,
  regtimestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado INT DEFAULT 1 NOT NULL,
  FOREIGN KEY (idruta) REFERENCES ruta (idruta)
 );

-- Categoria de los productos
CREATE TABLE categorias (
  idcategoria INT PRIMARY KEY AUTO_INCREMENT,
  nombrecategoria VARCHAR(50) NOT NULL
 );

 -- Unidad de los productos
CREATE TABLE unidades (
  idunidad INT PRIMARY KEY AUTO_INCREMENT,
  nombreunidad VARCHAR(50) NOT NULL
 );

-- Estatus
CREATE TABLE estatus (
  idestatus INT PRIMARY KEY AUTO_INCREMENT,
  estatus     VARCHAR(50) NOT NULL,
  clave       VARCHAR(20) NOT NULL
);

-- Productos (Confirmado plural)
CREATE TABLE productos (
  idproducto INT PRIMARY KEY AUTO_INCREMENT,
  idcategoria INT  NOT NULL,
  nombreproducto VARCHAR(150) NOT NULL,
  regtimestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado INT DEFAULT 1 NOT NULL,
  
  FOREIGN KEY (idcategoria) REFERENCES categorias (idcategoria)
);

-- Precios por producto + unidad + cliente se le da el precio 
CREATE TABLE precios (
  id INT PRIMARY KEY AUTO_INCREMENT,
  idproducto INT NOT NULL,
  idunidad      INT NOT NULL,
  idcliente     INT NOT NULL,
  preciounitario DECIMAL(12,2) NOT NULL,
  regtimestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado INT DEFAULT 1 NOT NULL,
  
   FOREIGN KEY (idproducto) REFERENCES productos (idproducto),
   FOREIGN KEY (idunidad) REFERENCES unidades (idunidad),
   FOREIGN KEY (idcliente) REFERENCES clientes (idcliente)
);

-- Embarques
CREATE TABLE embarque (
  idfolioembarque INT PRIMARY KEY AUTO_INCREMENT,
  idalmacen     INT NOT NULL,
  idusuario    INT NOT NULL,
  idalmacenista INT NOT NULL,
  idcliente     INT NOT NULL,
  regtimestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado INT DEFAULT 1 NOT NULL,
  
   FOREIGN KEY (idalmacen) REFERENCES almacenes (idalmacen),
   FOREIGN KEY (idusuario) REFERENCES usuarios (idusuario),
   FOREIGN KEY (idalmacenista) REFERENCES almacenistas (idalmacenista),
   FOREIGN KEY (idcliente) REFERENCES clientes (idcliente)

);

-- Detalle de los embarques
CREATE TABLE embarque_detalle (
  iddetalle INT PRIMARY KEY AUTO_INCREMENT,
  idfolioembarque INT NOT NULL,
  idproducto  INT NOT NULL,
  idunidad INT NOT NULL,
  cantidad DECIMAL(10,2) NOT NULL,
  preciounitario DECIMAL(12,2) NOT NULL,
  subtotal DECIMAL(14,2) NOT NULL,
  idestatus INT NOT NULL, -- Referencia a la tabla estatus
  regtimestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado INT DEFAULT 1 NOT NULL,
  
   FOREIGN KEY (idfolioembarque) REFERENCES embarque (idfolioembarque),
   FOREIGN KEY (idproducto) REFERENCES productos (idproducto),
   FOREIGN KEY (idunidad) REFERENCES unidades (idunidad),
   FOREIGN KEY (idestatus) REFERENCES estatus (idestatus)
);
```
