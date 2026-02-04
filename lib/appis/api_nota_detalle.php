<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);

require_once __DIR__ . '/conexion.php';

header('Content-Type: application/json; charset=UTF-8');

try {
    if ($_SERVER['REQUEST_METHOD'] != 'GET') {
        throw new Exception("Método no permitido.", 405);
    }
    if (!isset($_GET['idnota'])) {
        throw new Exception("El parámetro 'idnota' es obligatorio.", 400);
    }

    $idnota = intval($_GET['idnota']);

    // 1. Buscar información de la nota, embarque y cliente
    $sql_get_info = "SELECT e.idfolioembarque, e.idusuario, n.idcliente, c.nombrecliente AS nombre_cliente
                     FROM notas n
                     JOIN embarque e ON n.idembarque = e.idfolioembarque
                     JOIN clientes c ON n.idcliente = c.idcliente
                     WHERE n.idnota = ?";
    
    $stmt_get_info = $conn->prepare($sql_get_info);
    if ($stmt_get_info === false) {
        throw new Exception("Error al preparar la consulta de info: " . $conn->error, 500);
    }

    $stmt_get_info->bind_param("i", $idnota);
    if (!$stmt_get_info->execute()) {
        throw new Exception("Error al ejecutar la consulta de info: " . $stmt_get_info->error, 500);
    }

    $result_info = $stmt_get_info->get_result();
    $info = $result_info->fetch_assoc();
    $stmt_get_info->close();

    if (!$info) {
        throw new Exception("La nota #$idnota no tiene un embarque/cliente asociado o no existe.", 404);
    }

    $id_embarque = $info['idfolioembarque'];
    $id_usuario = $info['idusuario'];
    $id_cliente = $info['idcliente'];
    $nombre_cliente = $info['nombre_cliente'];

    if (empty($id_usuario)) {
        throw new Exception("El embarque #$id_embarque asociado a la nota no tiene un idusuario asignado.", 404);
    }

    // 2. Obtener el nombre del vendedor
    $nombre_vendedor = 'No asignado';
    $sql_vendedor = "SELECT nombre FROM usuarios WHERE idusuario = ?";
    $stmt_vendedor = $conn->prepare($sql_vendedor);
    if ($stmt_vendedor === false) {
        throw new Exception("Error al preparar la consulta de vendedor: " . $conn->error, 500);
    }

    $stmt_vendedor->bind_param("i", $id_usuario);
    if (!$stmt_vendedor->execute()) {
        throw new Exception("Error al ejecutar la consulta de vendedor: " . $stmt_vendedor->error, 500);
    }

    $result_vendedor = $stmt_vendedor->get_result();
    if ($vendedor_info = $result_vendedor->fetch_assoc()) {
        $nombre_vendedor = $vendedor_info['nombre'];
    }
    $stmt_vendedor->close();

    // 3. Obtener los detalles del embarque
    $sql_detalles = "SELECT ed.iddetalle, ed.cantidad, ed.preciounitario, ed.subtotal, ed.idestatus, ed.tipo_producto, p.nombreproducto, u.nombreunidad
                     FROM embarque_detalle AS ed
                     JOIN productos AS p ON ed.idproducto = p.idproducto
                     JOIN unidades AS u ON ed.idunidad = u.idunidad
                     WHERE ed.idfolioembarque = ?";

    $stmt_detalles = $conn->prepare($sql_detalles);
    if ($stmt_detalles === false) {
        throw new Exception("Error al preparar la consulta de detalles: " . $conn->error, 500);
    }

    $stmt_detalles->bind_param("i", $id_embarque);
    if (!$stmt_detalles->execute()) {
        throw new Exception("Error al ejecutar la consulta de detalles: " . $stmt_detalles->error, 500);
    }

    $result_detalles = $stmt_detalles->get_result();
    $detalles = [];
    while ($row = $result_detalles->fetch_assoc()) {
        // Renombrar claves para que coincidan con el frontend
        $detalles[] = [
            'iddetalle' => $row['iddetalle'],
            'cantidad' => $row['cantidad'],
            'precio' => $row['preciounitario'], // Frontend espera 'precio'
            'total' => $row['subtotal'],       // Frontend espera 'total'
            'idestatus' => $row['idestatus'],
            'nombreproducto' => $row['nombreproducto'],
            'nombreunidad' => $row['nombreunidad'],
            'tipo_producto' => $row['tipo_producto'], // Nuevo
        ];
    }
    $stmt_detalles->close();
    
    // 4. Construir la respuesta anidada
    $response_data = [
        'detalles' => $detalles,
        'vendedor' => [
            'nombre' => $nombre_vendedor
        ],
        'cliente' => [
            'id' => $id_cliente,
            'nombre' => $nombre_cliente
        ]
    ];

    http_response_code(200);
    echo json_encode(["success" => true, "data" => $response_data]);

} catch (Exception $e) {
    $errorCode = $e->getCode();
    if ($errorCode < 400 || $errorCode >= 600) {
        $errorCode = 500;
    }
    http_response_code($errorCode);
    echo json_encode(["success" => false, "error" => $e->getMessage(), "line" => $e->getLine()]);
}

$conn->close();
?>