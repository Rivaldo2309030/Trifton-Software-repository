<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

$servername = "srv571.hstgr.io";
$username = "u203835291_serviceOrder";
$password = "TritonSrv2025$%";
$dbname = "u203835291_orders";

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    http_response_code(500);
    die(json_encode(["error" => "Connection failed: " . $conn->connect_error]));
}

try {
    $sql = "SELECT idcamion, CONCAT(descripcion_camion, ' - ', chofer) AS nombre_camion FROM camiones WHERE estado_registro = 'Activo' ORDER BY idcamion ASC";
    $result = $conn->query($sql);

    $camiones = [];
    if ($result->num_rows > 0) {
        while($row = $result->fetch_assoc()) {
            $row['idcamion'] = (int)$row['idcamion'];
            $camiones[] = $row;
        }
    }
    http_response_code(200);
    echo json_encode($camiones);

} catch (mysqli_sql_exception $e) {
    http_response_code(500);
    echo json_encode(["error" => "SQL Error: " . $e->getMessage()]);
}

$conn->close();
?>