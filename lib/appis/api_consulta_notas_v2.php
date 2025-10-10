<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once __DIR__ . '/conexion.php';

if ($_SERVER['REQUEST_METHOD'] == 'GET') {
    try {
        $fecha = $_GET['fecha'] ?? date('Y-m-d');

        if (!preg_match("/^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[1-2][0-9]|3[0-1])$/", $fecha)) {
            throw new Exception("Formato de fecha inválido. Use YYYY-MM-DD.", 400);
        }

        $sql = "SELECT n.idnota, n.total, n.saldo, n.regtimestamp, c.nombrecliente AS nombre_cliente 
                FROM notas AS n
                JOIN clientes AS c ON n.idcliente = c.idcliente
                WHERE DATE(n.regtimestamp) = ?";

        $stmt = $conn->prepare($sql);
        $stmt->bind_param("s", $fecha);
        $stmt->execute();
        $result = $stmt->get_result();
        $notas = [];
        while ($row = $result->fetch_assoc()) {
            $notas[] = $row;
        }
        
        http_response_code(200);
        echo json_encode(["success" => true, "data" => $notas]);

    } catch (Exception $e) {
        // Si algo falla, capturamos la excepción y enviamos un error JSON
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