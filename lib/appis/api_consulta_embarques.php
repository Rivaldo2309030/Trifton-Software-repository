<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Función de log manual
function log_to_file($message) {
    $logFile = 'debug_log.txt';
    $timestamp = date('Y-m-d H:i:s');
    file_put_contents($logFile, "[$timestamp] $message\n", FILE_APPEND);
}

log_to_file("--- Script de Consulta INICIADO ---");

header('Content-Type: application/json');

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

$servername = "srv571.hstgr.io";
$username = "u203835291_serviceOrder";
$password = "TritonSrv2025$%";
$dbname = "u203835291_orders";

try {
    log_to_file("Intentando conectar a la BD...");
    $conn = new mysqli($servername, $username, $password, $dbname);
    log_to_file("Conexión a BD exitosa.");

    $fecha = isset($_GET['fecha']) ? $_GET['fecha'] : date('Y-m-d');
    log_to_file("Fecha a filtrar: $fecha");

    $sql = "
        SELECT 
            e.idfolioembarque,
            e.regtimestamp,
            e.estado AS estado_embarque,
            c.nombrecliente,
            v.nombrevendedor,
            a.nombre AS nombre_almacenista
        FROM 
            embarque e
        JOIN 
            clientes c ON e.idcliente = c.idcliente
        JOIN 
            vendedores v ON e.idvendedor = v.idvendedor
        JOIN 
            almacenistas a ON e.idalmacenista = a.idalmacenista
        WHERE 
            DATE(e.regtimestamp) = ?
        ORDER BY
            e.regtimestamp DESC
    ";
    log_to_file("SQL preparado. Intentando ejecutar...");

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $fecha);
    $stmt->execute();
    $result = $stmt->get_result();
    log_to_file("Consulta ejecutada. Filas: " . $result->num_rows);

    $embarques = [];
    if ($result->num_rows > 0) {
        while($row = $result->fetch_assoc()) {
            $embarques[] = $row;
        }
    }
    
    http_response_code(200);
    echo json_encode(['success' => true, 'data' => $embarques]);
    log_to_file("Respuesta 200 OK enviada.");

    $stmt->close();
    $conn->close();

} catch (Exception $e) {
    $errorMessage = 'ERROR CATCH: ' . $e->getMessage();
    log_to_file($errorMessage);
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => $errorMessage]);
}
?>
