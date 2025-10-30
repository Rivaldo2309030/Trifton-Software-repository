<?php
header('Content-Type: application/json');
include 'conexion.php';

// Asegurarse de que la solicitud es de tipo POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['status' => 'error', 'message' => 'Método no permitido. Se requiere POST.']);
    exit;
}

// Obtener el cuerpo de la solicitud
$input = json_decode(file_get_contents('php://input'), true);

// Validar que los datos necesarios están presentes
if (!isset($input['iddetalle']) || !isset($input['idestatus'])) {
    echo json_encode(['status' => 'error', 'message' => 'Datos incompletos. Se requiere iddetalle y idestatus.']);
    exit;
}

$iddetalle = $input['iddetalle'];
$idestatus = $input['idestatus'];

// Preparar la consulta para evitar inyección SQL
$sql = "UPDATE embarque_detalle SET idestatus = ? WHERE iddetalle = ?";

if ($stmt = mysqli_prepare($conn, $sql)) {
    // Vincular parámetros
    mysqli_stmt_bind_param($stmt, "ii", $idestatus, $iddetalle);

    // Ejecutar la consulta
    if (mysqli_stmt_execute($stmt)) {
        // Verificar si alguna fila fue afectada
        if (mysqli_stmt_affected_rows($stmt) > 0) {
            echo json_encode(['status' => 'success', 'message' => 'Estatus del producto actualizado correctamente.']);
        } else {
            echo json_encode(['status' => 'error', 'message' => 'No se encontró el producto en el embarque o el estatus ya era el mismo.']);
        }
    } else {
        // Error en la ejecución
        echo json_encode(['status' => 'error', 'message' => 'Error al actualizar el estatus: ' . mysqli_stmt_error($stmt)]);
    }

    // Cerrar la declaración
    mysqli_stmt_close($stmt);
} else {
    // Error en la preparación de la consulta
    echo json_encode(['status' => 'error', 'message' => 'Error al preparar la consulta: ' . mysqli_error($conn)]);
}

// Cerrar la conexión
mysqli_close($conn);
?>