<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=UTF-8');
require_once __DIR__ . '/conexion.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die(json_encode(["success" => false, "error" => "Método no permitido."]));
}

$input = json_decode(file_get_contents("php://input"), true);

// Validar campos requeridos
$required_fields = ['idfolioembarque', 'idalmacen', 'idusuario', 'idalmacenista', 'idcliente', 'detalles'];
foreach ($required_fields as $field) {
    if (empty($input[$field])) {
        http_response_code(400);
        die(json_encode(["success" => false, "error" => "Falta el campo requerido: " . $field]));
    }
}

$idfolioembarque = $input['idfolioembarque'];

$conn->begin_transaction();

try {
    // 1. Verificar que el embarque no esté procesado o cancelado
    $sql_check = "SELECT estado FROM embarque WHERE idfolioembarque = ? FOR UPDATE";
    $stmt_check = $conn->prepare($sql_check);
    $stmt_check->bind_param("i", $idfolioembarque);
    $stmt_check->execute();
    $result_check = $stmt_check->get_result();
    $embarque_data = $result_check->fetch_assoc();
    $stmt_check->close();

    if (!$embarque_data) {
        throw new Exception("Embarque no encontrado.", 404);
    }
    if ($embarque_data['estado'] != 1) { // Solo se pueden editar embarques activos
        throw new Exception("Este embarque no se puede editar porque ya ha sido procesado o cancelado.", 409);
    }

    // 2. Actualizar la cabecera del embarque
    $sql_update_header = "UPDATE embarque SET idalmacen = ?, idalmacenista = ?, idcliente = ? WHERE idfolioembarque = ?";
    $stmt_update_header = $conn->prepare($sql_update_header);
    $stmt_update_header->bind_param("iiii", 
        $input['idalmacen'], 
        $input['idalmacenista'], 
        $input['idcliente'], 
        $idfolioembarque
    );
    $stmt_update_header->execute();
    $stmt_update_header->close();

    // 3. Borrar los detalles antiguos del embarque
    $sql_delete_details = "DELETE FROM embarque_detalle WHERE idfolioembarque = ?";
    $stmt_delete_details = $conn->prepare($sql_delete_details);
    $stmt_delete_details->bind_param("i", $idfolioembarque);
    $stmt_delete_details->execute();
    $stmt_delete_details->close();

    // 4. Insertar los nuevos detalles del embarque
    if (!is_array($input['detalles']) || empty($input['detalles'])) {
        throw new Exception("El campo detalles debe ser un array con al menos un producto.");
    }

    $sql_insert_detail = "INSERT INTO embarque_detalle (idfolioembarque, idproducto, idunidad, cantidad, preciounitario, subtotal, idestatus) VALUES (?, ?, ?, ?, ?, ?, 1)"; // Estatus por defecto EE = 1
    $stmt_insert_detail = $conn->prepare($sql_insert_detail);

    foreach ($input['detalles'] as $detalle) {
        $cantidad = (float)$detalle['cantidad'];
        $precio = (float)$detalle['preciounitario'];
        $subtotal = $cantidad * $precio;

        $stmt_insert_detail->bind_param("iiidds", 
            $idfolioembarque, 
            $detalle['idproducto'], 
            $detalle['idunidad'], 
            $cantidad, 
            $precio, 
            $subtotal
        );
        $stmt_insert_detail->execute();
    }
    $stmt_insert_detail->close();

    // 5. Confirmar la transacción
    $conn->commit();

    http_response_code(200);
    echo json_encode(['success' => true, 'message' => 'Embarque #' . $idfolioembarque . ' actualizado correctamente.']);

} catch (Exception $e) {
    $conn->rollback();
    $errorCode = $e->getCode() >= 400 ? $e->getCode() : 500;
    die(json_encode(['success' => false, 'error' => $e->getMessage()]));
}

$conn->close();
?>