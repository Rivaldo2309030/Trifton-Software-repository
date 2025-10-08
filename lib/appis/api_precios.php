<?php
header('Content-Type: application/json');

// Recibir los parámetros de entrada
$idcliente = isset($_GET['idcliente']) ? (int)$_GET['idcliente'] : 0;
$idproducto = isset($_GET['idproducto']) ? (int)$_GET['idproducto'] : 0;
$idunidad = isset($_GET['idunidad']) ? (int)$_GET['idunidad'] : 0;

if ($idcliente === 0 || $idproducto === 0 || $idunidad === 0) {
    http_response_code(400);
    die(json_encode(['error' => 'Faltan parámetros requeridos: idcliente, idproducto, idunidad.']));
}

// Configuración de la base de datos
$servername = "srv571.hstgr.io";
$username = "u203835291_serviceOrder";
$password = "TritonSrv2025$%";
$dbname = "u203835291_orders";

// Crear conexión
$conn = new mysqli($servername, $username, $password, $dbname);

// Verificar conexión
if ($conn->connect_error) {
    http_response_code(500);
    die(json_encode(['error' => "Connection failed: " . $conn->connect_error]));
}

// Consulta para obtener el precio específico
$sql = "SELECT preciounitario FROM precios WHERE idcliente = ? AND idproducto = ? AND idunidad = ? AND estado = 1";

$stmt = $conn->prepare($sql);
$stmt->bind_param("iii", $idcliente, $idproducto, $idunidad);
$stmt->execute();
$result = $stmt->get_result();

$response = ['preciounitario' => null];

if ($result->num_rows > 0) {
    $row = $result->fetch_assoc();
    $response['preciounitario'] = (float)$row['preciounitario'];
}

http_response_code(200);
echo json_encode($response);

$stmt->close();
$conn->close();
?>
