<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

// 'conexion.php' ahora crea el objeto $conn y lo pone a nuestra disposición.
require_once 'conexion.php';

// Leer el cuerpo de la solicitud
$json = file_get_contents('php://input');
$data = json_decode($json, true);

if (!$data || !isset($data['pagos']) || !is_array($data['pagos'])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Estructura de datos inválida. Se esperaba un objeto con una clave "pagos" que sea un array.']);
    exit;
}

$pagos = $data['pagos'];
if (empty($pagos)) {
    http_response_code(200);
    echo json_encode(['success' => true, 'message' => 'No hay pagos para procesar.']);
    exit;
}

// No creamos una nueva conexión, usamos la que ya existe de conexion.php

$conn->begin_transaction();

$errores = [];
$exitosos = 0;

try {
    $stmt_insert_pago = $conn->prepare("INSERT INTO pagos (idnota, monto, tipo_pago, regtimestamp, idusuario) VALUES (?, ?, ?, ?, ?)");
    $stmt_update_nota = $conn->prepare("UPDATE notas SET saldo = saldo - ?, pagos = pagos + ? WHERE idnota = ?");

    if (!$stmt_insert_pago || !$stmt_update_nota) {
        throw new Exception("Error al preparar las consultas: " . $conn->error);
    }

    foreach ($pagos as $pago) {
        // Validar cada pago
        if (!isset($pago['idnota'], $pago['monto'], $pago['tipo_pago'], $pago['regtimestamp'], $pago['id_usuario'])) {
            $errores[] = "Pago inválido, faltan campos. Datos: " . json_encode($pago);
            continue;
        }

        $idnota = $pago['idnota'];
        $monto = $pago['monto'];
        $tipo_pago = $pago['tipo_pago'];
        $regtimestamp = $pago['regtimestamp'];
        $id_usuario = $pago['id_usuario'];

        // 1. Insertar el pago
        $stmt_insert_pago->bind_param("idssi", $idnota, $monto, $tipo_pago, $regtimestamp, $id_usuario);
        if (!$stmt_insert_pago->execute()) {
            $errores[] = "Error al insertar pago para la nota $idnota: " . $stmt_insert_pago->error;
            continue; // Saltar al siguiente pago
        }

        // 2. Actualizar el saldo y el monto pagado en la nota
        $stmt_update_nota->bind_param("ddi", $monto, $monto, $idnota);
        if (!$stmt_update_nota->execute()) {
            $errores[] = "Error al actualizar saldo para la nota $idnota: " . $stmt_update_nota->error;
            continue;
        }
        
        $exitosos++;
    }

    if (empty($errores)) {
        $conn->commit();
        echo json_encode(['success' => true, 'message' => "$exitosos pagos procesados correctamente."]);
    } else {
        $conn->rollback();
        http_response_code(409); // Conflict
        echo json_encode(['success' => false, 'error' => 'Ocurrieron errores y se revirtió la transacción.', 'detalles' => $errores]);
    }

    $stmt_insert_pago->close();
    $stmt_update_nota->close();

} catch (Exception $e) {
    $conn->rollback();
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
} finally {
    $conn->close();
}
?>