<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
header('Content-Type: application/json');

require_once __DIR__ . '/conexion.php';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);

    if (!isset($input['idnota']) || !isset($input['tipopago']) || !isset($input['monto'])) {
        http_response_code(400);
        echo json_encode(["success" => false, "error" => "Faltan parámetros requeridos."]);
        exit;
    }

    $idnota = intval($input['idnota']);
    $tipopago = $input['tipopago'];
    $valor = floatval($input['monto']);

    if ($valor <= 0) {
        http_response_code(400);
        echo json_encode(["success" => false, "error" => "El monto o cantidad debe ser mayor a cero."]);
        exit;
    }

    $conn->begin_transaction();
    $response_data = [];

    try {
        if ($tipopago == 'Caja') {
            if (!isset($input['iddetalle_embarque'])) {
                throw new Exception("Falta el iddetalle_embarque para el pago con Caja.");
            }
            $iddetalle_embarque = intval($input['iddetalle_embarque']);
            $cantidad_cajas = $valor;

            $stmt_precio = $conn->prepare("SELECT preciounitario FROM embarque_detalle WHERE iddetalle = ?");
            if (!$stmt_precio) throw new Exception("Error preparando consulta de precio: " . $conn->error);
            $stmt_precio->bind_param("i", $iddetalle_embarque);
            $stmt_precio->execute();
            $result_precio = $stmt_precio->get_result();
            if ($result_precio->num_rows === 0) {
                throw new Exception("No se encontró el producto en el embarque para obtener el precio de la caja.");
            }
            $item_detalle = $result_precio->fetch_assoc();
            $precio_unitario_caja = floatval($item_detalle['preciounitario']);
            $stmt_precio->close();

            $monto_credito = $cantidad_cajas * $precio_unitario_caja;

            $stmt_pago = $conn->prepare("INSERT INTO pagos_m (idnota, totalpago, tipopago, iddetalle_embarque, saldonota) VALUES (?, ?, ?, ?, 0)");
            if (!$stmt_pago) throw new Exception("Error preparando insert de pago: " . $conn->error);
            
            // Log para depuración
            $log_msg = "Attempting to insert: idnota=$idnota, cantidad_cajas=$cantidad_cajas, tipopago=$tipopago, iddetalle_embarque=$iddetalle_embarque\n";
            file_put_contents('log_pagos.txt', $log_msg, FILE_APPEND);

            $stmt_pago->bind_param("idsi", $idnota, $cantidad_cajas, $tipopago, $iddetalle_embarque);
            $stmt_pago->execute();
            $stmt_pago->close();

            $stmt_update = $conn->prepare("UPDATE notas SET saldo = saldo - ? WHERE idnota = ?");
            if (!$stmt_update) throw new Exception("Error preparando update de nota: " . $conn->error);
            $stmt_update->bind_param("di", $monto_credito, $idnota);
            $stmt_update->execute();
            $stmt_update->close();

            $stmt_final_data = $conn->prepare(
                "SELECT n.saldo, COALESCE(p.total_pagado, 0) AS monto_pagado_acumulado
                 FROM notas n
                 LEFT JOIN (
                     SELECT idnota, SUM(totalpago) AS total_pagado 
                     FROM pagos_m WHERE tipopago != 'Caja' AND estado = 1 GROUP BY idnota
                 ) p ON n.idnota = p.idnota
                 WHERE n.idnota = ?"
            );
            if (!$stmt_final_data) throw new Exception("Error preparando consulta final: " . $conn->error);
            $stmt_final_data->bind_param("i", $idnota);
            $stmt_final_data->execute();
            $final_data_result = $stmt_final_data->get_result()->fetch_assoc();

            $response_data = [
                "success" => true, 
                "message" => "Devolución de cajas registrada y crédito aplicado.", 
                "nuevo_saldo" => $final_data_result ? floatval($final_data_result['saldo']) : 0,
                "monto_pagado_acumulado" => $final_data_result ? floatval($final_data_result['monto_pagado_acumulado']) : 0
            ];

        } else {
            $monto_pago = $valor;
            $stmt_nota = $conn->prepare("SELECT saldo FROM notas WHERE idnota = ? FOR UPDATE");
            if (!$stmt_nota) throw new Exception("Error preparando consulta de nota: " . $conn->error);
            $stmt_nota->bind_param("i", $idnota);
            $stmt_nota->execute();
            $result_nota = $stmt_nota->get_result();

            if ($result_nota->num_rows === 0) throw new Exception("Nota no encontrada.");
            
            $nota = $result_nota->fetch_assoc();
            $saldo_actual = floatval($nota['saldo']);

            if ($monto_pago > $saldo_actual) throw new Exception("El monto del pago no puede ser mayor al saldo pendiente.");
            
            $nuevo_saldo = $saldo_actual - $monto_pago;

            $stmt_pago = $conn->prepare("INSERT INTO pagos_m (idnota, totalpago, tipopago, saldonota) VALUES (?, ?, ?, ?)");
            if (!$stmt_pago) throw new Exception("Error preparando insert de pago: " . $conn->error);
            $stmt_pago->bind_param("idsd", $idnota, $monto_pago, $tipopago, $nuevo_saldo);
            $stmt_pago->execute();
            $stmt_pago->close();

            $stmt_update_nota = $conn->prepare("UPDATE notas SET saldo = ? WHERE idnota = ?");
            if (!$stmt_update_nota) throw new Exception("Error preparando update de nota: " . $conn->error);
            $stmt_update_nota->bind_param("di", $nuevo_saldo, $idnota);
            $stmt_update_nota->execute();
            $stmt_update_nota->close();

            $stmt_acumulado = $conn->prepare(
                "SELECT SUM(totalpago) AS total_pagado 
                 FROM pagos_m WHERE idnota = ? AND tipopago != 'Caja' AND estado = 1"
            );
            if (!$stmt_acumulado) throw new Exception("Error preparando consulta de acumulado: " . $conn->error);
            $stmt_acumulado->bind_param("i", $idnota);
            $stmt_acumulado->execute();
            $acumulado_result = $stmt_acumulado->get_result()->fetch_assoc();
            
            $response_data = [
                "success" => true, 
                "message" => "Pago registrado.", 
                "nuevo_saldo" => $nuevo_saldo,
                "monto_pagado_acumulado" => $acumulado_result ? floatval($acumulado_result['total_pagado']) : 0
            ];
        }
        
        $conn->commit();
        http_response_code(200);
        echo json_encode($response_data);

    } catch (Exception $e) {
        $conn->rollback();
        http_response_code(500);
        echo json_encode(["success" => false, "error" => "Error en la transacción: " . $e->getMessage()]);
    }

} else {
    http_response_code(405);
    echo json_encode(["success" => false, "error" => "Método no permitido."]);
}
?>