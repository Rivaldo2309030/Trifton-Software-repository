<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once 'conexion.php'; 

if (!isset($_GET['idusuario'])) {
    echo json_encode(['success' => false, 'error' => 'El parámetro idusuario es requerido.']);
    http_response_code(400);
    exit;
}
$idusuario = intval($_GET['idusuario']);

try {
    $sql_notas = "SELECT 
                    n.idnota, n.idcliente, n.total, n.saldo, n.regtimestamp,
                    c.nombrecliente AS nombre_cliente, n.idalmacen,
                    a_salida.nombrealmacen AS nombre_almacen_salida,
                    a_origen.nombrealmacen AS nombre_almacen_origen,
                    u.nombre AS nombre_vendedor, n.pagos AS monto_pagado_acumulado
                  FROM notas n
                  JOIN clientes c ON n.idcliente = c.idcliente
                  JOIN usuarios u ON n.idusuario = u.idusuario
                  LEFT JOIN almacenes a_salida ON n.idalmacen = a_salida.idalmacen
                  LEFT JOIN embarque e ON n.idembarque = e.idfolioembarque
                  LEFT JOIN almacenes a_origen ON e.idalmacen = a_origen.idalmacen
                  WHERE n.idusuario = ? AND (n.saldo > 0 OR n.regtimestamp >= DATE_SUB(NOW(), INTERVAL 30 DAY))
                  ORDER BY n.regtimestamp DESC";

    $stmt_notas = $conn->prepare($sql_notas);
    if (!$stmt_notas) { throw new Exception("Error al preparar la consulta de notas: " . $conn->error); }
    
    $stmt_notas->bind_param("i", $idusuario);
    $stmt_notas->execute();

    // --- INICIO: Lógica de obtención de resultados compatible (bind_result) ---
    $meta = $stmt_notas->result_metadata();
    $fields = [];
    $row_data = [];
    while ($field = $meta->fetch_field()) {
        $fields[] = &$row_data[$field->name];
    }
    call_user_func_array([$stmt_notas, 'bind_result'], $fields);
    // --- FIN: Lógica de obtención de resultados compatible ---

    $notas_ids = [];
    $response_data = ['notas' => [], 'detalles' => [], 'pagos' => []];
    while ($stmt_notas->fetch()) {
        $row = [];
        foreach($row_data as $key => $val) {
            $row[$key] = $val;
        }
        $response_data['notas'][] = $row;
        $notas_ids[] = $row['idnota'];
    }
    $stmt_notas->close();

    if (!empty($notas_ids)) {
        $placeholders = implode(',', array_fill(0, count($notas_ids), '?'));
        $types = str_repeat('i', count($notas_ids));

        $params_ref = [];
        $params_ref[] = &$types;
        for ($i = 0; $i < count($notas_ids); $i++) {
            $params_ref[] = &$notas_ids[$i];
        }

        $sql_detalles = "SELECT 
                           ed.iddetalle, n.idnota as idnota_fk, ed.cantidad, ed.preciounitario as precio,
                           (ed.cantidad * ed.preciounitario) as total, ed.idestatus,
                           p.nombre as nombreproducto, u.nombre as nombreunidad
                         FROM notas n
                         JOIN embarque_detalle ed ON n.idembarque = ed.idfolioembarque
                         JOIN productos p ON ed.idproducto = p.id
                         JOIN unidades u ON ed.idunidad = u.id
                         WHERE n.idnota IN ($placeholders)";
        
        $stmt_detalles = $conn->prepare($sql_detalles);
        if (!$stmt_detalles) { throw new Exception("Error al preparar la consulta de detalles: " . $conn->error); }
        call_user_func_array(array($stmt_detalles, 'bind_param'), $params_ref);
        $stmt_detalles->execute();
        $result_detalles = $stmt_detalles->get_result(); // get_result suele funcionar para queries secundarias si la primera fue el problema
        while ($row = $result_detalles->fetch_assoc()) {
            $response_data['detalles'][] = $row;
        }
        $stmt_detalles->close();

        $sql_pagos = "SELECT idpago, idnota, monto, tipo_pago, regtimestamp FROM pagos WHERE idnota IN ($placeholders)";
        $stmt_pagos = $conn->prepare($sql_pagos);
        if (!$stmt_pagos) { throw new Exception("Error al preparar la consulta de pagos: " . $conn->error); }
        call_user_func_array(array($stmt_pagos, 'bind_param'), $params_ref);
        $stmt_pagos->execute();
        $result_pagos = $stmt_pagos->get_result();
        while ($row = $result_pagos->fetch_assoc()) {
            $response_data['pagos'][] = $row;
        }
        $stmt_pagos->close();
    }

    $conn->close();
    echo json_encode(['success' => true, 'data' => $response_data]);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => "Error de PHP/SQL: " . $e->getMessage()]);
}

?>