<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
require_once __DIR__ . '/conexion.php';

if ($_SERVER['REQUEST_METHOD'] == 'GET') {
    try {
        // Verificar si se proporciona un idcliente
        if (isset($_GET['idcliente'])) {
            // --- Lógica para obtener notas de un cliente específico ---
            $idcliente = $_GET['idcliente'];
            $fecha = $_GET['fecha'] ?? null;

            if (!filter_var($idcliente, FILTER_VALIDATE_INT)) {
                throw new Exception("ID de cliente inválido.", 400);
            }

            // Se buscan notas con saldo pendiente para ese cliente
            $sql = "SELECT 
                        n.idnota, 
                        n.total, 
                        n.saldo, 
                        n.regtimestamp, 
                        n.idalmacen, -- ID del almacén de salida
                        c.nombrecliente AS nombre_cliente,
                        u.nombre AS nombre_vendedor,
                        alm_salida.nombrealmacen AS nombre_almacen_salida,
                        alm_origen.nombrealmacen AS nombre_almacen_origen,
                        COALESCE(pagos_sum.total_pagado, 0) AS monto_pagado_acumulado
                    FROM notas AS n
                    JOIN clientes AS c ON n.idcliente = c.idcliente
                    JOIN usuarios AS u ON n.idusuario = u.idusuario
                    JOIN almacenes AS alm_salida ON n.idalmacen = alm_salida.idalmacen
                    LEFT JOIN embarque AS e ON n.idembarque = e.idfolioembarque
                    LEFT JOIN almacenes AS alm_origen ON e.idalmacen = alm_origen.idalmacen
                    LEFT JOIN (
                        SELECT idnota, SUM(totalpago) AS total_pagado
                        FROM pagos_m
                        WHERE estado = 1
                        GROUP BY idnota
                    ) AS pagos_sum ON n.idnota = pagos_sum.idnota
                    WHERE n.idcliente = ? AND n.saldo > 0";
            
            $params = [$idcliente];
            $types = "i";

            if ($fecha) {
                $sql .= " AND DATE(n.regtimestamp) = ?";
                $types .= "s";
                $params[] = $fecha;
            }

            $sql .= " ORDER BY n.regtimestamp DESC";

            $stmt = $conn->prepare($sql);
            if ($stmt === false) {
                throw new Exception("Error al preparar la consulta de notas: " . $conn->error);
            }
            $stmt->bind_param($types, ...$params);
            $stmt->execute();
            $result = $stmt->get_result();
            $data = [];
            while ($row = $result->fetch_assoc()) {
                $data[] = $row;
            }
            $response = ["type" => "notas", "data" => $data];

        } else {
            // --- Lógica para obtener la lista de clientes con notas pendientes ---
            $fecha = $_GET['fecha'] ?? null;
            $nombre_cliente_filtro = $_GET['nombre_cliente'] ?? null;

            $sql = "SELECT DISTINCT c.idcliente, c.nombrecliente 
                    FROM clientes AS c
                    JOIN notas AS n ON c.idcliente = n.idcliente
                    WHERE n.saldo > 0";
            
            $params = [];
            $types = "";

            if ($fecha) {
                $sql .= " AND DATE(n.regtimestamp) = ?";
                $types .= "s";
                $params[] = $fecha;
            }
            if ($nombre_cliente_filtro) {
                $sql .= " AND c.nombrecliente LIKE ?";
                $types .= "s";
                $params[] = "%" . $nombre_cliente_filtro . "%";
            }

            $sql .= " ORDER BY c.nombrecliente ASC";
            
            $stmt = $conn->prepare($sql);
            if ($stmt === false) {
                throw new Exception("Error al preparar la consulta de clientes: " . $conn->error);
            }
            if (!empty($params)) {
                $stmt->bind_param($types, ...$params);
            }
            $stmt->execute();
            $result = $stmt->get_result();
            
            $data = [];
            while ($row = $result->fetch_assoc()) {
                $data[] = $row;
            }
            $response = ["type" => "clientes", "data" => $data];
        }
        
        http_response_code(200);
        echo json_encode(["success" => true, "response" => $response]);

    } catch (Exception $e) {
        $errorCode = $e->getCode() == 400 ? 400 : 500;
        http_response_code($errorCode);
        echo json_encode(["success" => false, "error" => $e->getMessage()]);
    }

    if (isset($stmt)) $stmt->close();
    $conn->close();

} else {
    http_response_code(405);
    echo json_encode(["success" => false, "error" => "Método no permitido."]);
}
?>