<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

require_once __DIR__ . '/conexion.php'; // Usa la conexión centralizada

try {
    $sql = "SELECT idcliente, nombrecliente FROM clientes WHERE estado = 1 ORDER BY nombrecliente ASC";
    $result = $conn->query($sql);

    $clientes = [];
    if ($result->num_rows > 0) {
        while($row = $result->fetch_assoc()) {
            $row['idcliente'] = (int)$row['idcliente'];
            $clientes[] = $row;
        }
    }
    http_response_code(200);
    echo json_encode($clientes);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "error" => "SQL Error: " . $e->getMessage()]);
} finally {
    $conn->close();
}
?>