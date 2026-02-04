<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json; charset=UTF-8');

// 1. Unificar la conexión a la BD
require_once __DIR__ . '/conexion.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die(json_encode(["error" => "Método no permitido. Solo se acepta POST."]));
}

$input = json_decode(file_get_contents("php://input"), true);

// Iniciar transacción
$conn->begin_transaction();

try {
    // Validar campos requeridos
    $required_fields = ['id_embarque', 'id_usuario', 'id_cliente', 'id_almacen', 'detalles'];
    foreach ($required_fields as $field) {
        if (empty($input[$field])) {
            throw new Exception('Falta el campo requerido: ' . $field);
        }
    }

    if (!is_array($input['detalles']) || empty($input['detalles'])) {
        throw new Exception('El campo detalles debe ser un array con al menos un producto.');
    }

    // 2. Validar que el embarque no haya sido procesado
    $id_embarque = $input['id_embarque'];
    $sql_check = "SELECT estado FROM embarque WHERE idfolioembarque = ?";
    $stmt_check = $conn->prepare($sql_check);
    $stmt_check->bind_param("i", $id_embarque);
    $stmt_check->execute();
    $result_check = $stmt_check->get_result();
    if ($result_check->num_rows === 0) {
        throw new Exception("El embarque especificado no existe.");
    }
    $embarque_data = $result_check->fetch_assoc();
    if ($embarque_data['estado'] != 1) {
        throw new Exception("Este embarque ya ha sido procesado y no se puede volver a generar una nota.");
    }
    $stmt_check->close();

    // 3. Obtener los días de pago del cliente
    $id_cliente = $input['id_cliente'];
    $sql_cliente = "SELECT diaspago FROM clientes WHERE idcliente = ?";
    $stmt_cliente = $conn->prepare($sql_cliente);
    $stmt_cliente->bind_param("i", $id_cliente);
    $stmt_cliente->execute();
    $result_cliente = $stmt_cliente->get_result();
    if ($result_cliente->num_rows === 0) {
        throw new Exception("Cliente no encontrado.");
    }
    $cliente_data = $result_cliente->fetch_assoc();
    $dias_pago = (int)$cliente_data['diaspago'];
    $stmt_cliente->close();

    // 3. Calcular el total y el saldo a partir de los detalles
    $total = 0;
    foreach ($input['detalles'] as $detalle) {
        $cantidad = (float)$detalle['cantidad'];
        $precio = (float)$detalle['precio'];
        $total += $cantidad * $precio;
    }
    $saldo = $total;

    // 4. Insertar en la tabla `notas` con la fecha de pago calculada
    $sql_nota = "INSERT INTO notas (idusuario, idcliente, idalmacen, idembarque, total, saldo, credito_dias, fechapago, pagos) VALUES (?, ?, ?, ?, ?, ?, ?, DATE_ADD(CURDATE(), INTERVAL ? DAY), 0.00)";
    $stmt_nota = $conn->prepare($sql_nota);
    
    $stmt_nota->bind_param("iiiiddis", 
        $input['id_usuario'], 
        $id_cliente, 
        $input['id_almacen'], 
        $input['id_embarque'], 
        $total, 
        $saldo,
        $dias_pago, // Guardamos los días de crédito usados
        $dias_pago  // Usamos los días para el cálculo de la fecha
    );
    $stmt_nota->execute();
    $idnota = $conn->insert_id;
    $stmt_nota->close();

    // 5. Preparar la inserción para `nota_detalle`
    $sql_detalle = "INSERT INTO nota_detalle (idnota, idproducto, idunidad, precio, total, tipo_producto) VALUES (?, ?, ?, ?, ?, ?)";
    $stmt_detalle = $conn->prepare($sql_detalle);

    // 6. Iterar y guardar los detalles de la nota
    foreach ($input['detalles'] as $detalle) {
        $cantidad = (float)$detalle['cantidad'];
        $precio = (float)$detalle['precio'];
        $subtotal_detalle = $cantidad * $precio;
        $tipo_producto = isset($detalle['tipo_producto']) ? $detalle['tipo_producto'] : 'P'; // Default a 'P'

        $stmt_detalle->bind_param("iiidds", 
            $idnota, 
            $detalle['idproducto'], 
            $detalle['idunidad'], 
            $precio, 
            $subtotal_detalle,
            $tipo_producto
        );
        $stmt_detalle->execute();
    }
    $stmt_detalle->close();

    // 7. Actualizar el estado del embarque original a 'Procesado'
    $sql_update_embarque = "UPDATE embarque SET estado = 2 WHERE idfolioembarque = ?"; // Asumimos que estado 2 = Procesado/Facturado
    $stmt_update = $conn->prepare($sql_update_embarque);
    $stmt_update->bind_param("i", $input['id_embarque']);
    $stmt_update->execute();
    $stmt_update->close();

    // 8. Actualizar el estatus de todos los productos del embarque a 'Salida por Pedido' (SP = 2)
    $sql_update_detalles = "UPDATE embarque_detalle SET idestatus = 2 WHERE idfolioembarque = ?";
    $stmt_update_detalles = $conn->prepare($sql_update_detalles);
    $stmt_update_detalles->bind_param("i", $input['id_embarque']);
    $stmt_update_detalles->execute();
    $stmt_update_detalles->close();

    // 9. Confirmar la transacción
    $conn->commit();

    // 10. Recuperar la nota recién creada para devolverla
    $sql_select_new = "
        SELECT 
            n.idnota, n.total, n.saldo, n.regtimestamp, n.idalmacen,
            c.nombrecliente AS nombre_cliente,
            u.nombre AS nombre_vendedor,
            alm_salida.nombrealmacen AS nombre_almacen_salida,
            alm_origen.nombrealmacen AS nombre_almacen_origen,
            0 AS monto_pagado_acumulado
        FROM notas AS n
        JOIN clientes AS c ON n.idcliente = c.idcliente
        JOIN usuarios AS u ON n.idusuario = u.idusuario
        JOIN almacenes AS alm_salida ON n.idalmacen = alm_salida.idalmacen
        LEFT JOIN embarque AS e ON n.idembarque = e.idfolioembarque
        LEFT JOIN almacenes AS alm_origen ON e.idalmacen = alm_origen.idalmacen
        WHERE n.idnota = ?";
    
    $stmt_select = $conn->prepare($sql_select_new);
    $stmt_select->bind_param("i", $idnota);
    $stmt_select->execute();
    $result_new_nota = $stmt_select->get_result();
    $nueva_nota_data = $result_new_nota->fetch_assoc();
    $stmt_select->close();

    http_response_code(201);
    echo json_encode([
        'success' => true, 
        'message' => 'Nota creada correctamente.', 
        'idnota' => $idnota,
        'nota' => $nueva_nota_data
    ]);

} catch (Exception $e) {
    $conn->rollback();
    $errorMessage = 'Error en transacción: ' . $e->getMessage();
    // Log the error to a file
    file_put_contents('error_log_generar_nota.txt', date('Y-m-d H:i:s') . ' - ' . $errorMessage . "\n", FILE_APPEND);
    http_response_code(500);
    die(json_encode(['success' => false, 'error' => $errorMessage]));
}

$conn->close();
?>
