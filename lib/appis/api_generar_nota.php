<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=UTF-8');
header("Access-Control-Allow-Origin: *");

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

$servername = "srv571.hstgr.io";
$username = "u203835291_serviceOrder";
$password = "TritonSrv2025$%";
$dbname = "u203835291_orders";

$conn = new mysqli($servername, $username, $password, $dbname);
$conn->set_charset('utf8mb4');

if ($conn->connect_error) {
    http_response_code(500);
    die(json_encode(["error" => "Connection failed: " . $conn->connect_error]));
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die(json_encode(["error" => "Método no permitido. Solo se acepta POST."]));
}

$input = json_decode(file_get_contents("php://input"), true);

// Validar campos requeridos
$required_fields = ['id_embarque', 'id_usuario', 'id_cliente', 'id_almacen', 'detalles'];
foreach ($required_fields as $field) {
    if (empty($input[$field])) {
        http_response_code(400);
        die(json_encode(['error' => 'Falta el campo requerido: ' . $field]));
    }
}

if (!is_array($input['detalles']) || empty($input['detalles'])) {
    http_response_code(400);
    die(json_encode(['error' => 'El campo detalles debe ser un array con al menos un producto.']));
}

// Iniciar transacción
$conn->begin_transaction();

try {
    // 1. Calcular el total y el saldo a partir de los detalles
    $total = 0;
    foreach ($input['detalles'] as $detalle) {
        $cantidad = (float)$detalle['cantidad'];
        $precio = (float)$detalle['precio'];
        $total += $cantidad * $precio;
    }
    $saldo = $total; // Al crear la nota, el saldo es el total

    // 2. Insertar en la tabla `notas`
    $sql_nota = "INSERT INTO notas (idusuario, idcliente, idalmacen, idembarque, total, saldo, fechapago) VALUES (?, ?, ?, ?, ?, ?, NOW())"; // Asumimos fechapago es ahora, se puede ajustar
    $stmt_nota = $conn->prepare($sql_nota);
    $stmt_nota->bind_param("iiidd", 
        $input['id_usuario'], 
        $input['id_cliente'], 
        $input['id_almacen'], 
        $input['id_embarque'], 
        $total, 
        $saldo
    );
    $stmt_nota->execute();

    // 3. Obtener el ID de la nota recién creada
    $idnota = $conn->insert_id;

    // 4. Preparar la inserción para `nota_detalle`
    $sql_detalle = "INSERT INTO nota_detalle (idnota, idproducto, idunidad, precio, total) VALUES (?, ?, ?, ?, ?)";
    $stmt_detalle = $conn->prepare($sql_detalle);

    // 5. Iterar y guardar los detalles de la nota
    foreach ($input['detalles'] as $detalle) {
        $cantidad = (float)$detalle['cantidad'];
        $precio = (float)$detalle['precio'];
        $subtotal_detalle = $cantidad * $precio;

        $stmt_detalle->bind_param("iiidd", 
            $idnota, 
            $detalle['idproducto'], 
            $detalle['idunidad'], 
            $precio, 
            $subtotal_detalle
        );
        $stmt_detalle->execute();
    }

    // 6. (Opcional) Actualizar el estado del embarque original para marcarlo como procesado
    $sql_update_embarque = "UPDATE embarque SET estado = 2 WHERE idfolioembarque = ?"; // Asumimos que estado 2 = Procesado
    $stmt_update = $conn->prepare($sql_update_embarque);
    $stmt_update->bind_param("i", $input['id_embarque']);
    $stmt_update->execute();

    // 7. Si todo fue bien, confirmar la transacción
    $conn->commit();

    http_response_code(201);
    echo json_encode(['success' => true, 'message' => 'Nota creada correctamente.', 'idnota' => $idnota]);

} catch (Exception $e) {
    // 8. Si algo falló, revertir la transacción
    $conn->rollback();
    http_response_code(500);
    die(json_encode(['error' => 'Error al generar la nota: ' . $e->getMessage()]));
}

$stmt_nota->close();
$stmt_detalle->close();
$stmt_update->close();
$conn->close();
?>
