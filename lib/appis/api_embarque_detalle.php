<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=UTF-8');
header("Access-Control-Allow-Origin: *");

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

$servername = "srv571.hstgr.io";
$username = "u203835291_serviceOrder";
$password = "TritonSrv2025$%";
$dbname = "u203835291_orders";

$conn = new mysqli($servername, $username, $password, $dbname);
$conn->set_charset('utf8mb4');

if ($conn->connect_error) {
    http_response_code(500);
    die(json_encode(["error" => "Connection failed: " . $conn->connect_error]));
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    die(json_encode(["error" => "Método no permitido. Solo se acepta GET."]));
}

if (!isset($_GET['id']) || empty($_GET['id'])) {
    http_response_code(400);
    die(json_encode(["error" => "Falta el parámetro ID del embarque."]));
}

$idfolioembarque = (int)$_GET['id'];

try {
    $sql = "
        SELECT 
            ed.iddetalle,
            ed.idproducto,
            ed.idunidad,
            ed.cantidad,
            ed.preciounitario,
            ed.subtotal,
            p.nombreproducto,
            u.nombreunidad
        FROM 
            embarque_detalle ed
        JOIN 
            productos p ON ed.idproducto = p.idproducto
        JOIN 
            unidades u ON ed.idunidad = u.idunidad
        WHERE 
            ed.idfolioembarque = ?
    ";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $idfolioembarque);
    $stmt->execute();
    $result = $stmt->get_result();

    $detalles = [];
    while($row = $result->fetch_assoc()) {
        $detalles[] = $row;
    }

    http_response_code(200);
    echo json_encode(["success" => true, "data" => $detalles]);

    $stmt->close();
    $conn->close();

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "error" => "Error en el servidor: " . $e->getMessage()]);
}
?>
