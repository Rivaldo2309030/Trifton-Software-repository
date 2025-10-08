<?php
header('Content-Type: application/json');

// Configuración de la base de datos
$servername = "srv571.hstgr.io";
$username = "u203835291_serviceOrder";
$password = "TritonSrv2025$%";
$dbname = "u203835291_orders";

// Crear conexión
$conn = new mysqli($servername, $username, $password, $dbname);

// Verificar conexión
if ($conn->connect_error) {
    http_response_code(500);
    die(json_encode(['error' => 'Connection failed: ' . $conn->connect_error]));
}

// Solo aceptamos POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die(json_encode(['error' => 'Method Not Allowed']));
}

// Leer el JSON de entrada
$input = json_decode(file_get_contents('php://input'), true);

// Validar campos principales
$required_fields = ['idalmacen', 'idvendedor', 'idalmacenista', 'idcliente', 'detalles'];
foreach ($required_fields as $field) {
    if (empty($input[$field])) {
        http_response_code(400);
        die(json_encode(['error' => 'Falta el campo requerido: ' . $field]));
    }
}

// Validar que los detalles no estén vacíos y tengan la estructura correcta
if (!is_array($input['detalles']) || empty($input['detalles'])) {
    http_response_code(400);
    die(json_encode(['error' => 'El campo detalles debe ser un array con al menos un producto.']));
}

// Iniciar transacción
$conn->begin_transaction();

try {
    // 1. Insertar en la tabla 'embarque'
    $sql_embarque = "INSERT INTO embarque (idalmacen, idvendedor, idalmacenista, idcliente) VALUES (?, ?, ?, ?)";
    $stmt_embarque = $conn->prepare($sql_embarque);
    $stmt_embarque->bind_param("iiii", $input['idalmacen'], $input['idvendedor'], $input['idalmacenista'], $input['idcliente']);
    $stmt_embarque->execute();

    // 2. Obtener el ID del embarque recién creado
    $idfolioembarque = $conn->insert_id;

    // 3. Preparar la inserción para 'embarque_detalle'
    $sql_detalle = "INSERT INTO embarque_detalle (idfolioembarque, idproducto, idunidad, cantidad, preciounitario, subtotal, idestatus) VALUES (?, ?, ?, ?, ?, ?, ?)";
    $stmt_detalle = $conn->prepare($sql_detalle);

    // 4. Iterar y guardar los detalles
    foreach ($input['detalles'] as $detalle) {
        if (empty($detalle['idproducto']) || empty($detalle['idunidad']) || !isset($detalle['cantidad']) || !isset($detalle['preciounitario'])) {
            throw new Exception('Cada producto en detalles debe tener idproducto, idunidad, cantidad y preciounitario.');
        }
        
        $cantidad = (float)$detalle['cantidad'];
        $precio = (float)$detalle['preciounitario'];
        $subtotal = $cantidad * $precio;
        $idestatus = 1; // Asignar un estatus por defecto

        $stmt_detalle->bind_param("iiiddsi", 
            $idfolioembarque, 
            $detalle['idproducto'], 
            $detalle['idunidad'], 
            $cantidad, 
            $precio, 
            $subtotal,
            $idestatus
        );
        $stmt_detalle->execute();
    }

    // 5. Si todo fue bien, confirmar la transacción
    $conn->commit();

    http_response_code(201);
    echo json_encode(['success' => true, 'message' => 'Embarque creado correctamente.', 'idfolioembarque' => $idfolioembarque]);

} catch (Exception $e) {
    // 6. Si algo falló, revertir la transacción
    $conn->rollback();
    http_response_code(500);
    die(json_encode(['error' => 'Error al guardar el embarque: ' . $e->getMessage()]));
}

$stmt_embarque->close();
$stmt_detalle->close();
$conn->close();
?>
