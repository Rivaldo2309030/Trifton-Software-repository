<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
require_once __DIR__ . '/conexion.php';

// Esta API devuelve todas las notas, sin filtrar por saldo

try {
    $fecha = $_GET['fecha'] ?? null;
    $nombre_cliente_filtro = $_GET['nombre_cliente'] ?? null;
    $idcliente = $_GET['idcliente'] ?? null;
    $tipo_producto_filter = $_GET['tipo_producto'] ?? null; // Nuevo filtro

    $sql = "SELECT 
                n.idnota, 
                n.total, 
                n.saldo, 
                n.regtimestamp, 
                c.idcliente,
                c.nombrecliente AS nombre_cliente,
                u.nombre AS nombre_vendedor,
                MAX(ed.tipo_producto) as tipo_producto, 
                COALESCE(pagos_sum.total_pagado, 0) AS monto_pagado_acumulado,
                ult_pago.tipopago AS last_payment_type,
                -- Cálculos de Cajas (Usando CANTIDAD)
                SUM(CASE WHEN ed.tipo_producto = 'C' THEN ed.cantidad ELSE 0 END) as total_cajas,
                COALESCE(pagos_caja.total_devuelto, 0) as cajas_devueltas,
                (SUM(CASE WHEN ed.tipo_producto = 'C' THEN ed.cantidad ELSE 0 END) - COALESCE(pagos_caja.total_devuelto, 0)) as saldo_cajas
            FROM notas AS n
            JOIN clientes AS c ON n.idcliente = c.idcliente
            JOIN usuarios AS u ON n.idusuario = u.idusuario
            JOIN embarque_detalle AS ed ON n.idembarque = ed.idfolioembarque 
            LEFT JOIN (
                SELECT idnota, SUM(totalpago) AS total_pagado
                FROM pagos_m
                WHERE estado = 1 AND tipopago != 'Caja'
                GROUP BY idnota
            ) AS pagos_sum ON n.idnota = pagos_sum.idnota
            LEFT JOIN (
                SELECT idnota, SUM(totalpago) AS total_devuelto
                FROM pagos_m
                WHERE estado = 1 AND tipopago = 'Caja'
                GROUP BY idnota
            ) AS pagos_caja ON n.idnota = pagos_caja.idnota
            LEFT JOIN pagos_m AS ult_pago ON ult_pago.id = (
                SELECT id
                FROM pagos_m
                WHERE idnota = n.idnota
                ORDER BY regtimestamp DESC
                LIMIT 1
            )";
    
    $params = [];
    $types = "";
    $whereClauses = [];

    if ($idcliente) {
        $whereClauses[] = "c.idcliente = ?";
        $types .= "i";
        $params[] = $idcliente;
    }
    if ($fecha) {
        $whereClauses[] = "DATE(n.regtimestamp) = ?";
        $types .= "s";
        $params[] = $fecha;
    }
    if ($nombre_cliente_filtro) {
        $whereClauses[] = "c.nombrecliente LIKE ?";
        $types .= "s";
        $params[] = "%" . $nombre_cliente_filtro . "%";
    }
    if ($tipo_producto_filter) { // Aplicar filtro de tipo_producto si se proporciona
        $whereClauses[] = "ed.tipo_producto = ?";
        $types .= "s";
        $params[] = $tipo_producto_filter;
    }

    if (!empty($whereClauses)) {
        $sql .= " WHERE " . implode(" AND ", $whereClauses);
    }

    $sql .= " GROUP BY n.idnota ORDER BY n.regtimestamp DESC"; // Agrupar para evitar duplicados y ordenar

    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        throw new Exception("Error al preparar la consulta de notas: " . $conn->error);
    }
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $result = $stmt->get_result();
    
    $notas = [];
    while ($row = $result->fetch_assoc()) {
        $notas[] = $row;
    }
    
    http_response_code(200);
    echo json_encode(["success" => true, "data" => $notas]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "error" => $e->getMessage()]);
} finally {
    if (isset($stmt)) $stmt->close();
    $conn->close();
}
?>