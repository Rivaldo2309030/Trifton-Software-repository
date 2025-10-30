<?php
header('Content-Type: application/json');
include 'conexion.php';

$idNota = isset($_GET['id_nota']) ? intval($_GET['id_nota']) : 0;

if ($idNota <= 0) {
    echo json_encode(['success' => false, 'message' => 'ID de nota no válido.']);
    exit;
}

$response = ['success' => false];

try {
    // Buscar el último pago para la nota especificada, usando la tabla y columnas correctas
    $stmt = $conn->prepare(
        "SELECT 
            totalpago AS monto, 
            tipopago AS tipo_pago, 
            regtimestamp AS fecha 
         FROM pagos_m 
         WHERE idnota = ? 
         ORDER BY regtimestamp DESC 
         LIMIT 1"
    );
    $stmt->bind_param("i", $idNota);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $pago = $result->fetch_assoc();
        $response['success'] = true;
        // Los alias en el SQL aseguran que las claves del JSON sean las que el frontend espera
        $response['data'] = [
            'monto' => $pago['monto'],
            'tipo_pago' => $pago['tipo_pago'],
            'fecha' => $pago['fecha']
        ];
    } else {
        // Si no hay pagos, devolvemos éxito pero con datos nulos
        $response['success'] = true;
        $response['data'] = null;
    }

    $stmt->close();
} catch (Exception $e) {
    $response['message'] = 'Error en el servidor: ' . $e->getMessage();
}

$conn->close();
echo json_encode($response);
?>
