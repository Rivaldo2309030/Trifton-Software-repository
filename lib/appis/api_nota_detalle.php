<?php
require_once __DIR__ . '/conexion.php';

if ($_SERVER['REQUEST_METHOD'] == 'GET') {
    try {
        if (!isset($_GET['idnota'])) {
            throw new Exception("El parámetro 'idnota' es obligatorio.", 400);
        }

        $idnota = intval($_GET['idnota']);

        $sql = "SELECT nd.id, nd.cantidad, nd.precio, nd.total, p.nombreproducto, u.nombreunidad
                FROM nota_detalle AS nd
                JOIN productos AS p ON nd.idproducto = p.idproducto
                JOIN unidades AS u ON nd.idunidad = u.idunidad
                WHERE nd.idnota = ?";

        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $idnota);
        $stmt->execute();
        $result = $stmt->get_result();
        $detalles = [];
        while ($row = $result->fetch_assoc()) {
            $detalles[] = $row;
        }
        
        http_response_code(200);
        echo json_encode(["success" => true, "data" => $detalles]);

    } catch (Exception $e) {
        $errorCode = $e->getCode() == 400 ? 400 : 500;
        http_response_code($errorCode);
        echo json_encode(["success" => false, "error" => $e->getMessage()]);
    }

    if (isset($stmt)) $stmt->close();
    $conn->close();

} else {
    http_response_code(405);
    echo json_encode(["success" => false, "error" => "Método no permitido."]);
}
?>