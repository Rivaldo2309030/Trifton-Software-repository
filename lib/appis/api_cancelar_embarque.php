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

if (empty($input['idfolioembarque'])) {
    http_response_code(400);
    die(json_encode(["success" => false, "error" => "El campo 'idfolioembarque' es obligatorio."]));
}

$idfolioembarque = $input['idfolioembarque'];

$conn->begin_transaction();

try {
    // 1. Verificar el estado actual del embarque para evitar cancelar uno ya procesado
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

    if ($embarque_data['estado'] == 2) { // 2 = Procesado (ya tiene una nota)
        throw new Exception("No se puede cancelar un embarque que ya ha sido procesado.", 409); // 409 Conflict
    }
    
    if ($embarque_data['estado'] == 0) { // 0 = Cancelado
        throw new Exception("Este embarque ya ha sido cancelado previamente.", 409);
    }

    // 2. Actualizar el estado a 0 (Cancelado)
    $sql_update = "UPDATE embarque SET estado = 0 WHERE idfolioembarque = ?";
    $stmt_update = $conn->prepare($sql_update);
    $stmt_update->bind_param("i", $idfolioembarque);
    $stmt_update->execute();
    
    if ($stmt_update->affected_rows > 0) {
        $conn->commit();
        http_response_code(200);
        echo json_encode(['success' => true, 'message' => 'Embarque cancelado correctamente.']);
    } else {
        throw new Exception("No se pudo actualizar el embarque.");
    }

    $stmt_update->close();

} catch (Exception $e) {
    $conn->rollback();
    $errorCode = $e->getCode() >= 400 ? $e->getCode() : 500;
    http_response_code($errorCode);
    die(json_encode(['success' => false, 'error' => $e->getMessage()]));
}

$conn->close();
?>