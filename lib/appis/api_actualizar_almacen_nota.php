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
if (empty($input['idnota']) || empty($input['idalmacen'])) {
    http_response_code(400);
    die(json_encode(["success" => false, "error" => "Los campos 'idnota' y 'idalmacen' son obligatorios."]));
}

$idnota = $input['idnota'];
$idalmacen = $input['idalmacen'];

try {
    $sql = "UPDATE notas SET idalmacen = ? WHERE idnota = ?";
    $stmt = $conn->prepare($sql);
    
    if ($stmt === false) {
        throw new Exception("Error al preparar la consulta: " . $conn->error);
    }
    
    $stmt->bind_param("ii", $idalmacen, $idnota);
    
    if ($stmt->execute()) {
        if ($stmt->affected_rows > 0) {
            http_response_code(200);
            echo json_encode(['success' => true, 'message' => 'Almacén actualizado correctamente.']);
        } else {
            // No rows were updated, maybe the note ID doesn't exist or the value was the same
            http_response_code(200); // Still a success from the client's perspective
            echo json_encode(['success' => true, 'message' => 'No se realizaron cambios, el almacén ya era el asignado o la nota no existe.']);
        }
    } else {
        throw new Exception("Error al ejecutar la consulta: " . $stmt->error);
    }
    
    $stmt->close();
    $conn->close();

} catch (Exception $e) {
    http_response_code(500);
    die(json_encode(['success' => false, 'error' => $e->getMessage()]));
}
?>
