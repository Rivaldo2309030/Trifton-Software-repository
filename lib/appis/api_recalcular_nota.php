<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=UTF-8');
require_once __DIR__ . '/conexion.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die(json_encode(["success" => false, "error" => "Método no permitido."]));
}

$input = json_decode(file_get_contents("php://input"), true);

if (empty($input['idnota'])) {
    http_response_code(400);
    die(json_encode(["success" => false, "error" => "El campo 'idnota' es obligatorio."]));
}

$idnota = $input['idnota'];

// IDs de estatus que NO suman al total. Asumimos 5=Merma, 6=Rechazado.
$estatusExcluidos = [5, 6];
$placeholders = implode(',', array_fill(0, count($estatusExcluidos), '?')); // Crea ?,?
$types = str_repeat('i', count($estatusExcluidos)); // Crea ii

$conn->begin_transaction();

try {
    // 1. Obtener info de la nota y el embarque asociado
    $sql_nota = "SELECT idembarque, total, saldo FROM notas WHERE idnota = ?";
    $stmt_nota = $conn->prepare($sql_nota);
    $stmt_nota->bind_param("i", $idnota);
    $stmt_nota->execute();
    $result_nota = $stmt_nota->get_result();
    $nota_data = $result_nota->fetch_assoc();
    $stmt_nota->close();

    if (!$nota_data) {
        throw new Exception("Nota no encontrada.");
    }

    $id_embarque = $nota_data['idembarque'];
    $viejo_total = (float)$nota_data['total'];
    $viejo_saldo = (float)$nota_data['saldo'];

    // 2. Calcular el nuevo total sumando subtotales de embarque_detalle con estatus = 2 (Salida Pedido)
    $sql_recalc = "SELECT SUM(subtotal) as nuevo_total FROM embarque_detalle WHERE idfolioembarque = ? AND idestatus = 2";
    $stmt_recalc = $conn->prepare($sql_recalc);
    $stmt_recalc->bind_param("i", $id_embarque);
    $stmt_recalc->execute();
    $result_recalc = $stmt_recalc->get_result();
    $recalc_data = $result_recalc->fetch_assoc();
    $stmt_recalc->close();

    $nuevo_total = ($recalc_data['nuevo_total'] === null) ? 0.00 : (float)$recalc_data['nuevo_total'];

    // 3. Calcular el nuevo saldo
    $monto_pagado = $viejo_total - $viejo_saldo;
    $nuevo_saldo = $nuevo_total - $monto_pagado;
    if ($nuevo_saldo < 0) {
        $nuevo_saldo = 0; // El saldo no puede ser negativo
    }

    // 4. Actualizar la nota con los nuevos totales
    $sql_update = "UPDATE notas SET total = ?, saldo = ? WHERE idnota = ?";
    $stmt_update = $conn->prepare($sql_update);
    $stmt_update->bind_param("ddi", $nuevo_total, $nuevo_saldo, $idnota);
    $stmt_update->execute();
    $stmt_update->close();

    $conn->commit();

    http_response_code(200);
    echo json_encode([
        'success' => true, 
        'message' => 'Nota recalculada correctamente.',
        'nuevo_total' => $nuevo_total,
        'nuevo_saldo' => $nuevo_saldo
    ]);

} catch (Exception $e) {
    $conn->rollback();
    http_response_code(500);
    die(json_encode(['success' => false, 'error' => $e->getMessage()]));
}

$conn->close();
?>