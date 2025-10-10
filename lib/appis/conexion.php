<?php
// Forzar la respuesta a ser siempre JSON, incluso en caso de error fatal.
header("Content-Type: application/json");

// Habilitar el reporte de excepciones en MySQLi para que el try-catch funcione.
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

$servername = "srv571.hstgr.io";
$username = "u203835291_serviceOrder";
$password = "TritonSrv2025$%";
$dbname = "u203835291_orders";

try {
    // Intentar la conexión usando TUS nombres de variable
    $conn = new mysqli($servername, $username, $password, $dbname);
    $conn->set_charset("utf8");

} catch (Exception $e) {
    // Si la conexión falla por CUALQUIER razón, la atrapamos aquí.
    http_response_code(500); // Internal Server Error
    
    // Devolvemos un JSON válido con el error real.
    echo json_encode([
        "success" => false,
        "error" => "Excepción de conexión a la BD: " . $e->getMessage()
    ]);
    
    exit();
}
?>