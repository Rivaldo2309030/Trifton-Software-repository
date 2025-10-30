<?php
header('Content-Type: application/json');
require_once __DIR__ . '/conexion.php';

// Esta API devuelve todas las notas, sin filtrar por saldo

try {
    $sql = "SELECT 
                n.idnota, 
                n.total, 
                n.saldo, 
                n.regtimestamp, 
                c.nombrecliente AS nombre_cliente,
                u.nombre AS nombre_vendedor,
                COALESCE(pagos_sum.total_pagado, 0) AS monto_pagado_acumulado
            FROM notas AS n
            JOIN clientes AS c ON n.idcliente = c.idcliente
            JOIN usuarios AS u ON n.idusuario = u.idusuario
            LEFT JOIN (
                SELECT idnota, SUM(totalpago) AS total_pagado
                FROM pagos_m
                WHERE estado = 1
                GROUP BY idnota
            ) AS pagos_sum ON n.idnota = pagos_sum.idnota
            ORDER BY n.regtimestamp DESC";

    $stmt = $conn->prepare($sql);
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