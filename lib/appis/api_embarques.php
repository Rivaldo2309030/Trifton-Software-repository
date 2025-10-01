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

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $sql = "SELECT e.idembarque, e.fecha, e.total,\n                   a.nombre_almacen,\n                   c.nombre_cliente,\n                   u.nombre_unidad\n            FROM embarques e\n            JOIN almacen a ON e.idalmacen = a.idalmacen\n            JOIN clientes c ON e.idcliente = c.idcliente\n            JOIN unidades u ON e.idunidad = u.idunidad\n            ORDER BY e.idembarque DESC";
    $result = $conn->query($sql);

    if ($result->num_rows > 0) {
        $embarques = [];
        while ($row = $result->fetch_assoc()) {
            $embarques[] = $row;
        }
        http_response_code(200);
        echo json_encode(["success" => true, "data" => $embarques]);
    } else {
        http_response_code(200);
        echo json_encode(["success" => false, "message" => "No se encontraron embarques."]);
    }
}

if ($method === 'POST') {
    $input = json_decode(file_get_contents("php://input"), true);

    if (!$input) {
        http_response_code(400);
        echo json_encode(["error" => "JSON inválido"]);
        exit;
    }

    // --- CAMPOS REQUERIDOS ---
    $required_fields = ['idalmacen', 'idalmacenista', 'idunidad', 'idcliente', 'total'];
    foreach ($required_fields as $field) {
        if (!isset($input[$field])) {
            http_response_code(400);
            echo json_encode(["success" => false, "error" => "Falta el campo requerido: " . $field]);
            exit;
        }
    }

    // --- CAMPOS ADICIONALES (los que sí se llenan en el formulario) ---
    $camion_chofer = $input['camion_chofer'] ?? null;
    $tipo_movimiento = $input['tipo_movimiento'] ?? null;
    $motivo_cancelacion = $input['motivo_cancelacion'] ?? null;

    // --- Asignación de variables ---
    $idalmacen = $input['idalmacen'];
    $idalmacenista = $input['idalmacenista'];
    $idunidad = $input['idunidad'];
    $idcliente = $input['idcliente'];
    $total = $input['total'];

    // --- ACTUALIZACIÓN DE LA CONSULTA SQL ---
    // Se quitan los campos automáticos (estatus, fecha_salida) y se pone un valor por defecto para estado_proceso
    $sql = "INSERT INTO embarques (
                idalmacen, idalmacenista, idunidad, idcliente, total,
                camion_chofer, tipo_movimiento, motivo_cancelacion,
                estado_proceso, reg_timestamp, estado_registro
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'Activo', NOW(), 1)";

    try {
        $stmt = $conn->prepare($sql);
        // --- ACTUALIZACIÓN DE BIND_PARAM ---
        // i: integer, d: double, s: string
        $stmt->bind_param("iiiidsss",
            $idalmacen, $idalmacenista, $idunidad, $idcliente, $total,
            $camion_chofer, $tipo_movimiento, $motivo_cancelacion
        );

        if ($stmt->execute()) {
            $newId = $conn->insert_id;
            http_response_code(201);
            echo json_encode(["success" => true, "idembarque" => $newId]);
        } else {
            http_response_code(500);
            echo json_encode(["success" => false, "error" => $stmt->error]);
        }
        $stmt->close();
    } catch (mysqli_sql_exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "error" => "Error SQL: " . $e->getMessage()]);
    }
}

$conn->close();
?>