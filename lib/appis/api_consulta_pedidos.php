<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

// --- Conexión a la base de datos ---
$servername = "srv571.hstgr.io";
$username = "u203835291_serviceOrder";
$password = "TritonSrv2025$%";
$dbname = "u203835291_orders";

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    $conn->set_charset('utf8mb4');

    // --- Obtener parámetros de filtro ---
    $idcliente = isset($_GET['idcliente']) && !empty($_GET['idcliente']) ? (int)$_GET['idcliente'] : null;
    $searchTerm = isset($_GET['producto']) && !empty($_GET['producto']) ? '%' . $conn->real_escape_string($_GET['producto']) . '%' : null;

    // --- Construcción de la consulta SQL ---
    $sql = "
        SELECT 
            ed.iddetalle,
            ed.cantidad,
            ed.preciounitario,
            ed.subtotal,
            ed.regtimestamp,
            p.nombreproducto,
            u.nombreunidad,
            c.nombrecliente,
            e.idfolioembarque
        FROM 
            embarque_detalle ed
        JOIN 
            embarque e ON ed.idfolioembarque = e.idfolioembarque
        JOIN 
            productos p ON ed.idproducto = p.idproducto
        JOIN 
            unidades u ON ed.idunidad = u.idunidad
        JOIN 
            clientes c ON e.idcliente = c.idcliente
    ";

    $whereClauses = [];
    $params = [];
    $types = '';

    if ($idcliente !== null) {
        $whereClauses[] = "e.idcliente = ?";
        $params[] = $idcliente;
        $types .= 'i';
    }

    if ($searchTerm !== null) {
        $whereClauses[] = "p.nombreproducto LIKE ?";
        $params[] = $searchTerm;
        $types .= 's';
    }

    if (!empty($whereClauses)) {
        $sql .= " WHERE " . implode(' AND ', $whereClauses);
    }

    $sql .= " ORDER BY ed.regtimestamp DESC LIMIT 200"; // Limitar a 200 resultados

    // --- Preparar y ejecutar la consulta ---
    $stmt = $conn->prepare($sql);

    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }

    $stmt->execute();
    $result = $stmt->get_result();

    $ventas = [];
    if ($result->num_rows > 0) {
        while($row = $result->fetch_assoc()) {
            $ventas[] = $row;
        }
    }
    
    http_response_code(200);
    echo json_encode(['success' => true, 'data' => $ventas]);

    $stmt->close();
    $conn->close();

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Error en el servidor: ' . $e->getMessage()]);
}
?>
