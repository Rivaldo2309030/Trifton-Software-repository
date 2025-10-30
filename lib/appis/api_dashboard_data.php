<?php
header("Content-Type: application/json; charset=UTF-8");
include 'conexion.php'; // Asegúrate de que este archivo contenga la conexión a tu base de datos

$response = ["status" => "error", "message" => ""];

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }

    // Establecer la zona horaria a la de tu servidor si es necesario, o UTC
    // $conn->query("SET time_zone = '+00:00';"); // Ejemplo para UTC

    $today = date('Y-m-d');
    $yesterday = date('Y-m-d', strtotime('-1 day'));

    // --- Pedidos ---
    $pedidosCurrent = 0;
    $pedidosPrevious = 0;
    $stmt = $conn->prepare("SELECT COUNT(*) AS count FROM notas WHERE DATE(regtimestamp) = ? AND estado = 1");
    $stmt->bind_param("s", $today);
    $stmt->execute();
    $result = $stmt->get_result();
    if ($row = $result->fetch_assoc()) {
        $pedidosCurrent = $row['count'];
    }
    $stmt->bind_param("s", $yesterday);
    $stmt->execute();
    $result = $stmt->get_result();
    if ($row = $result->fetch_assoc()) {
        $pedidosPrevious = $row['count'];
    }
    $stmt->close();

    // --- Embarques ---
    $embarquesCurrent = 0;
    $embarquesPrevious = 0;
    $stmt = $conn->prepare("SELECT COUNT(*) AS count FROM embarque WHERE DATE(regtimestamp) = ? AND estado = 1");
    $stmt->bind_param("s", $today);
    $stmt->execute();
    $result = $stmt->get_result();
    if ($row = $result->fetch_assoc()) {
        $embarquesCurrent = $row['count'];
    }
    $stmt->bind_param("s", $yesterday);
    $stmt->execute();
    $result = $stmt->get_result();
    if ($row = $result->fetch_assoc()) {
        $embarquesPrevious = $row['count'];
    }
    $stmt->close();

    // --- Clientes (nuevos clientes registrados hoy) ---
    $clientesCurrent = 0;
    $clientesPrevious = 0;
    $stmt = $conn->prepare("SELECT COUNT(*) AS count FROM clientes WHERE DATE(regtimestamp) = ? AND estado = 1");
    $stmt->bind_param("s", $today);
    $stmt->execute();
    $result = $stmt->get_result();
    if ($row = $result->fetch_assoc()) {
        $clientesCurrent = $row['count'];
    }
    $stmt->bind_param("s", $yesterday);
    $stmt->execute();
    $result = $stmt->get_result();
    if ($row = $result->fetch_assoc()) {
        $clientesPrevious = $row['count'];
    }
    $stmt->close();

    // --- Calcular tendencias ---
    $pedidosTrend = calculateTrend($pedidosCurrent, $pedidosPrevious);
    $embarquesTrend = calculateTrend($embarquesCurrent, $embarquesPrevious);
    $clientesTrend = calculateTrend($clientesCurrent, $clientesPrevious);

    $response["status"] = "success";
    $response["message"] = "Datos del dashboard obtenidos correctamente.";
    $response["data"] = [
        "pedidos" => [
            "current" => $pedidosCurrent,
            "previous" => $pedidosPrevious,
            "trend" => $pedidosTrend
        ],
        "embarques" => [
            "current" => $embarquesCurrent,
            "previous" => $embarquesPrevious,
            "trend" => $embarquesTrend
        ],
        "clientes" => [
            "current" => $clientesCurrent,
            "previous" => $clientesPrevious,
            "trend" => $clientesTrend
        ]
    ];

    $conn->close();

} catch (Exception $e) {
    $response["message"] = "Error: " . $e->getMessage();
}

echo json_encode($response);

function calculateTrend($current, $previous) {
    if ($previous == 0) {
        return $current > 0 ? "+100%" : "0%";
    }
    $percentage = (($current - $previous) / $previous) * 100;
    return sprintf("%+.0f%%", $percentage);
}
?>