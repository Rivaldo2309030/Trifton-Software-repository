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

// Consulta para obtener el precio específico con fallback
$preciounitario = null;

// Intento 1: Buscar precio para el cliente específico
$sql_specific = "SELECT preciounitario FROM precios WHERE idcliente = ? AND idproducto = ? AND idunidad = ? AND estado = 1";
$stmt_specific = $conn->prepare($sql_specific);
$stmt_specific->bind_param("iii", $idcliente, $idproducto, $idunidad);
$stmt_specific->execute();
$result_specific = $stmt_specific->get_result();

if ($result_specific->num_rows > 0) {
    $row = $result_specific->fetch_assoc();
    $preciounitario = (float)$row['preciounitario'];
} else {
    // Intento 2: Si no se encontró, buscar precio para el cliente MOSTRADOR (idcliente = 0)
    $idcliente_mostrador = 91; // ID del cliente MOSTRADOR
    $sql_mostrador = "SELECT preciounitario FROM precios WHERE idcliente = ? AND idproducto = ? AND idunidad = ? AND estado = 1";
    $stmt_mostrador = $conn->prepare($sql_mostrador);
    $stmt_mostrador->bind_param("iii", $idcliente_mostrador, $idproducto, $idunidad);
    $stmt_mostrador->execute();
    $result_mostrador = $stmt_mostrador->get_result();

    if ($result_mostrador->num_rows > 0) {
        $row = $result_mostrador->fetch_assoc();
        $preciounitario = (float)$row['preciounitario'];
    }
    $stmt_mostrador->close();
}
$stmt_specific->close();

$response = ['preciounitario' => $preciounitario];

http_response_code(200);
echo json_encode($response);

$conn->close();?>
