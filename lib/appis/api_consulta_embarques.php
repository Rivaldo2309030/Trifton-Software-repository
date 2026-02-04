<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

$servername = "srv571.hstgr.io";
$username = "u203835291_serviceOrder";
$password = "TritonSrv2025$%";
$dbname = "u203835291_orders";

try {
    $conn = new mysqli($servername, $username, $password, $dbname);

    $fecha = isset($_GET['fecha']) ? $_GET['fecha'] : date('Y-m-d');
    $idAlmacen = isset($_GET['idalmacen']) ? $_GET['idalmacen'] : null;

    $sql = "
        SELECT 
            e.idfolioembarque,
            e.regtimestamp,
            e.estado AS estado_embarque,
            e.idcliente,
            e.idalmacen,
            e.idusuario,
            e.idalmacenista, -- Añadido
            e.tipo_venta, -- Nuevo: tipo de venta (Crédito/Contado)
            c.nombrecliente AS nombre_cliente,
            u.nombre AS nombreusuario,
            a.nombre AS nombre_almacenista
        FROM 
            embarque e
        JOIN 
            clientes c ON e.idcliente = c.idcliente
        JOIN 
            usuarios u ON e.idusuario = u.idusuario
        JOIN 
            almacenistas a ON e.idalmacenista = a.idalmacenista
        WHERE 
            DATE(e.regtimestamp) = ?
    ";

    $params = ["s", $fecha];
    if ($idAlmacen !== null && $idAlmacen !== '') {
        $sql .= " AND e.idalmacen = ?";
        $params[0] .= "i";
        $params[] = $idAlmacen;
    }

    $sql .= " ORDER BY e.regtimestamp DESC";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param(...$params);
    $stmt->execute();
    $result = $stmt->get_result();

    $embarques = [];
    if ($result->num_rows > 0) {
        while($row = $result->fetch_assoc()) {
            $embarques[] = $row;
        }
    }
    
    http_response_code(200);
    echo json_encode(['success' => true, 'data' => $embarques]);

    $stmt->close();
    $conn->close();

} catch (Exception $e) {
    $errorMessage = 'ERROR CATCH: ' . $e->getMessage();
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => $errorMessage]);
}
?>