<?php
header("Content-Type: application/json");
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

$servername = "srv571.hstgr.io";
$username   = "u203835291_serviceOrder";
$password   = "TritonSrv2025$%";
$dbname     = "u203835291_orders";

try {
    // Configura la zona horaria para todos los los edpoits que usen conexion.php
    $conn = new mysqli($servername, $username, $password, $dbname);
    $conn->set_charset("utf8mb4");
    date_default_timezone_set('America/Mexico_City');
    try {
        $conn->query("SET time_zone = '-06:00'");
    } catch (Exception $tzEx) {
        // Ignorar error si la zona horaria ya está establecida o hay problemas
    }

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error"   => "Excepción de conexión a la BD: " . $e->getMessage()
    ]);
    exit();
}
?>