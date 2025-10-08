<?php
header('Content-Type: application/json');

// Configuración de la base de datos
$servername = "srv571.hstgr.io";
$username = "u203835291_serviceOrder";
$password = "TritonSrv2025$%";
$dbname = "u203835291_orders";

// Crear conexión
$conn = new mysqli($servername, $username, $password, $dbname);

// Verificar conexión
if ($conn->connect_error) {
  die(json_encode(['error' => "Connection failed: " . $conn->connect_error]));
}

// Consulta para obtener los vendedores
$sql = "SELECT idvendedor, nombrevendedor FROM vendedores WHERE estado = 1 ORDER BY nombrevendedor ASC";
$result = $conn->query($sql);

$vendedores = [];
if ($result->num_rows > 0) {
  while($row = $result->fetch_assoc()) {
    $vendedores[] = $row;
  }
}

echo json_encode($vendedores);

$conn->close();
?>