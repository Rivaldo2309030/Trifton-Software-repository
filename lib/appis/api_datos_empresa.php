<?php
header('Content-Type: application/json');
include 'conexion.php';

// Asumimos que siempre queremos los datos de la empresa con id 1
$idempresa = 1;

$sql = "SELECT nombre, direccion, telefono FROM empresas WHERE idempresa = ?";
$stmt = $conn->prepare($sql);

if ($stmt === false) {
    echo json_encode(['success' => false, 'error' => 'Error en la preparación de la consulta: ' . $conn->error]);
    exit();
}

$stmt->bind_param("i", $idempresa);

if ($stmt->execute()) {
    $result = $stmt->get_result();
    if ($result->num_rows > 0) {
        $empresa = $result->fetch_assoc();
        echo json_encode(['success' => true, 'data' => $empresa]);
    } else {
        echo json_encode(['success' => false, 'error' => 'No se encontró la empresa con el ID especificado.']);
    }
} else {
    echo json_encode(['success' => false, 'error' => 'Error al ejecutar la consulta: ' . $stmt->error]);
}

$stmt->close();
$conn->close();
?>
