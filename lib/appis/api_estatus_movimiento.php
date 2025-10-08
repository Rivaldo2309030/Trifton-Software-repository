<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

// El usuario debe reemplazar esto con los detalles de conexión de su base de datos de Hostinger
$servername = "localhost";
$username = "u282972421_angel"; // Usuario de la base de datos
$password = "ContraseñA123"; // Contraseña de la base de datos
$dbname = "u282972421_maga"; // Nombre de la base de datos

// Crear conexión
$conn = new mysqli($servername, $username, $password, $dbname);

// Verificar conexión
if ($conn->connect_error) {
  die("Connection failed: " . $conn->connect_error);
}

// Establecer el conjunto de caracteres a utf8
$conn->set_charset("utf8");

// Consulta para obtener los estatus de movimiento
$sql = "SELECT idestatus, nombre_estatus FROM estatus_movimiento";
$result = $conn->query($sql);

$estatus = array();

if ($result && $result->num_rows > 0) {
  // Salida de datos de cada fila
  while($row = $result->fetch_assoc()) {
    $estatus[] = $row;
  }
  echo json_encode($estatus);
} else {
  // Enviar un array vacío si no hay resultados o si hay un error en la consulta
  echo json_encode([]);
}
$conn->close();
?>
