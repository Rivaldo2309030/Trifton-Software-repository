<?php
header('Content-Type: application/json');

require_once __DIR__ . '/conexion.php';


// Solo aceptamos POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die(json_encode(['error' => 'Method Not Allowed']));
}

// Leer el JSON de entrada
$input = json_decode(file_get_contents('php://input'), true);

// Iniciar transacción
$conn->begin_transaction();

try {
    // Validar campos principales
    $required_fields = ['idalmacen', 'idusuario', 'idalmacenista', 'idcliente', 'detalles'];
    foreach ($required_fields as $field) {
        if (empty($input[$field])) {
            throw new Exception('Falta el campo requerido: ' . $field);
        }
    }

    if (!is_array($input['detalles']) || empty($input['detalles'])) {
        throw new Exception('El campo detalles debe ser un array con al menos un producto.');
    }
    
    $idcliente = $input['idcliente'];
    $tipo_venta = isset($input['tipo_venta']) ? (int)$input['tipo_venta'] : 1; // Default a 1 (Crédito) si no se provee

    // 1. Insertar en la tabla 'embarque'
    $sql_embarque = "INSERT INTO embarque (idalmacen, idusuario, idalmacenista, idcliente, tipo_venta) VALUES (?, ?, ?, ?, ?)";
    $stmt_embarque = $conn->prepare($sql_embarque);
    if ($stmt_embarque === false) {
        throw new Exception("Error al preparar la consulta de embarque: " . $conn->error);
    }
    $stmt_embarque->bind_param("iiiii", $input['idalmacen'], $input['idusuario'], $input['idalmacenista'], $idcliente, $tipo_venta);
    $stmt_embarque->execute();

    // 2. Obtener el ID del embarque recién creado
    $idfolioembarque = $conn->insert_id;
    $stmt_embarque->close();

    // 3. Preparar la inserción para 'embarque_detalle'
    $sql_detalle = "INSERT INTO embarque_detalle (idfolioembarque, idproducto, idunidad, cantidad, preciounitario, subtotal, idestatus, tipo_producto) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
    $stmt_detalle = $conn->prepare($sql_detalle);
    if ($stmt_detalle === false) {
        throw new Exception("Error al preparar la consulta de detalle de embarque: " . $conn->error);
    }

    // 4. Iterar y guardar los detalles
    foreach ($input['detalles'] as $detalle) {
        if (empty($detalle['idproducto']) || empty($detalle['idunidad']) || !isset($detalle['cantidad']) || !isset($detalle['preciounitario'])) {
            throw new Exception('Cada producto en detalles debe tener idproducto, idunidad, cantidad y preciounitario.');
        }
        
        $cantidad = (float)$detalle['cantidad'];
        $precio = (float)$detalle['preciounitario'];
        $subtotal = $cantidad * $precio;
        $idestatus = 1; // Asignar un estatus por defecto
        $tipo_producto = isset($detalle['tipo_producto']) ? $detalle['tipo_producto'] : 'P'; // Default a 'P'

        $stmt_detalle->bind_param("iiidddis", 
            $idfolioembarque, 
            $detalle['idproducto'], 
            $detalle['idunidad'], 
            $cantidad, 
            $precio, 
            $subtotal,
            $idestatus,
            $tipo_producto
        );
        $stmt_detalle->execute();
    }
    $stmt_detalle->close();

    // 5. Si todo fue bien, confirmar la transacción
    $conn->commit();

    http_response_code(201);
    echo json_encode(['success' => true, 'message' => 'Embarque creado correctamente.', 'idfolioembarque' => $idfolioembarque]);

} catch (Exception $e) {
    $conn->rollback();
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Error al guardar el embarque: ' . $e->getMessage(), 'line' => $e->getLine()]);
}

$conn->close();
?>