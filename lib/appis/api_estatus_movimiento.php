<?php
header('Content-Type: application/json');
require_once __DIR__ . '/conexion.php';

if ($_SERVER['REQUEST_METHOD'] == 'GET') {
    try {
        $sql = "SELECT idestatus, estatus, clave FROM estatus ORDER BY idestatus ASC";
        $result = $conn->query($sql);

        if ($result === false) {
            throw new Exception("Error al ejecutar la consulta: " . $conn->error);
        }

        $estatus_list = [];
        while ($row = $result->fetch_assoc()) {
            $estatus_list[] = $row;
        }

        http_response_code(200);
        echo json_encode(["success" => true, "data" => $estatus_list]);

    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "error" => $e->getMessage()]);
    }

    $conn->close();
} else {
    http_response_code(405);
    echo json_encode(["success" => false, "error" => "Método no permitido."]);
}
?>