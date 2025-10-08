<?php
ini_set('display_errors', 1); // Cambiar a 0 en producción
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

// Iniciar transacción
$conn->begin_transaction();

try {
    // Validar campos requeridos
    $required_fields = ['id_embarque', 'id_usuario', 'id_cliente', 'id_almacen', 'detalles'];
    foreach ($required_fields as $field) {
        if (empty($input[$field])) {
            throw new Exception('Falta el campo requerido: ' . $field);
        }
    }

    if (!is_array($input['detalles']) || empty($input['detalles'])) {
        throw new Exception('El campo detalles debe ser un array con al menos un producto.');
    }

    // 1. Calcular el total y el saldo a partir de los detalles
    $total = 0;
    foreach ($input['detalles'] as $detalle) {
        $cantidad = (float)$detalle['cantidad'];
        $precio = (float)$detalle['precio'];
        $total += $cantidad * $precio;
    }
    $saldo = $total;

    // 2. Insertar en la tabla `notas`
    $sql_nota = "INSERT INTO notas (idusuario, idcliente, idalmacen, idembarque, total, saldo, fechapago) VALUES (?, ?, ?, ?, ?, ?, NOW())";
    $stmt_nota = $conn->prepare($sql_nota);
    // CORRECCIÓN: Se cambió "iiidd" a "iiiidd" para que coincida con los 6 parámetros
    $stmt_nota->bind_param("iiiidd", 
        $input['id_usuario'], 
        $input['id_cliente'], 
        $input['id_almacen'], 
        $input['id_embarque'], 
        $total, 
        $saldo
    );
    $stmt_nota->execute();
    $idnota = $conn->insert_id;

    // 3. Preparar la inserción para `nota_detalle`
    $sql_detalle = "INSERT INTO nota_detalle (idnota, idproducto, idunidad, precio, total) VALUES (?, ?, ?, ?, ?)";
    $stmt_detalle = $conn->prepare($sql_detalle);

    // 4. Iterar y guardar los detalles de la nota
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

    // 5. Actualizar el estado del embarque original
    $sql_update_embarque = "UPDATE embarque SET estado = 2 WHERE idfolioembarque = ?"; // Asumimos que estado 2 = Procesado
    $stmt_update = $conn->prepare($sql_update_embarque);
    $stmt_update->bind_param("i", $input['id_embarque']);
    $stmt_update->execute();

    // 6. Confirmar la transacción
    $conn->commit();

    http_response_code(201);
    echo json_encode(['success' => true, 'message' => 'Nota creada correctamente.', 'idnota' => $idnota]);

} catch (Exception $e) {
    $conn->rollback();
    $errorMessage = 'Error en transacción: ' . $e->getMessage();
    http_response_code(500);
    die(json_encode(['error' => $errorMessage]));
}

$conn->close();
?>
