<?php
header('Content-Type: application/json');
require_once __DIR__ . '/conexion.php';

if (!isset($_GET['idnota']) || !filter_var($_GET['idnota'], FILTER_VALIDATE_INT)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'ID de nota no válido o no proporcionado.']);
    exit;
}

$idnota = $_GET['idnota'];

try {
    $sql = "SELECT id, idnota, totalpago, tipopago, regtimestamp 
            FROM pagos_m 
            WHERE idnota = ? AND estado = 1 
            ORDER BY regtimestamp ASC";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $idnota);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $pagos = [];
    while ($row = $result->fetch_assoc()) {
        $pagos[] = [
            'idpago' => $row['id'],
            'idnota' => $row['idnota'],
            'monto' => $row['totalpago'],
            'tipo_pago' => $row['tipopago'],
            'fecha' => $row['regtimestamp']
        ];
    }
    
    http_response_code(200);
    echo json_encode(["success" => true, "data" => $pagos]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "error" => $e->getMessage()]);
} finally {
    if (isset($stmt)) $stmt->close();
    $conn->close();
}
?>