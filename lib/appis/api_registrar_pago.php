<?php
require_once __DIR__ . '/conexion.php';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);

    if (!isset($input['idnota']) || !isset($input['monto']) || !isset($input['tipopago'])) {
        http_response_code(400);
        echo json_encode(["success" => false, "error" => "Faltan parámetros requeridos."]);
        exit;
    }

    $idnota = intval($input['idnota']);
    $monto = floatval($input['monto']);
    $tipopago = $input['tipopago'];

    if ($monto <= 0) {
        http_response_code(400);
        echo json_encode(["success" => false, "error" => "El monto debe ser mayor a cero."]);
        exit;
    }

    $conn->begin_transaction();

    try {
        $stmt = $conn->prepare("SELECT saldo FROM notas WHERE idnota = ? FOR UPDATE");
        $stmt->bind_param("i", $idnota);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows === 0) {
            throw new Exception("Nota no encontrada.");
        }

        $nota = $result->fetch_assoc();
        $saldo_actual = floatval($nota['saldo']);

        if ($monto > $saldo_actual) {
            throw new Exception("El monto del pago no puede ser mayor al saldo pendiente.");
        }

        $nuevo_saldo = $saldo_actual - $monto;

        $stmt_pago = $conn->prepare("INSERT INTO pagos_m (idnota, totalpago, tipopago, saldonota) VALUES (?, ?, ?, ?)");
        $stmt_pago->bind_param("idsd", $idnota, $monto, $tipopago, $nuevo_saldo);
        $stmt_pago->execute();

        $stmt_nota = $conn->prepare("UPDATE notas SET saldo = ?, pagos = pagos + 1 WHERE idnota = ?");
        $stmt_nota->bind_param("di", $nuevo_saldo, $idnota);
        $stmt_nota->execute();

        $conn->commit();

        http_response_code(200);
        echo json_encode(["success" => true, "message" => "Pago registrado.", "nuevo_saldo" => $nuevo_saldo]);

    } catch (Exception $e) {
        $conn->rollback();
        http_response_code(500);
        echo json_encode(["success" => false, "error" => $e->getMessage()]);
    }

} else {
    http_response_code(405);
    echo json_encode(["success" => false, "error" => "Método no permitido."]);
}
?>