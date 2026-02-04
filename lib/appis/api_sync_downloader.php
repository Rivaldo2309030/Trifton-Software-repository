<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
require_once __DIR__ . '/conexion.php';

// --- Helper para enviar respuesta ---
function send_response($data) {
    global $conn;
    echo json_encode(['success' => true, 'data' => $data]);
    $conn->close();
    exit;
}

function send_error($message, $code = 500) {
    global $conn;
    http_response_code($code);
    echo json_encode(['success' => false, 'error' => $message]);
    if ($conn) $conn->close();
    exit;
}

// --- Lógica Principal ---
if (!isset($_GET['entity'])) {
    send_error('No se especificó la entidad a descargar.', 400);
}

$entity = $_GET['entity'];

try {
    $data = [];
    $sql = '';

    switch ($entity) {
        case 'clientes':
            $sql = "SELECT idcliente AS id, nombrecliente AS nombre FROM clientes WHERE estado = 1";
            break;
        case 'productos':
            $sql = "SELECT idproducto AS id, nombreproducto AS nombre FROM productos WHERE estado = 1";
            break;
        case 'almacenes':
            $sql = "SELECT idalmacen AS id, nombrealmacen AS nombre FROM almacenes WHERE estado = 1";
            break;
        case 'almacenistas':
            $sql = "SELECT idalmacenista AS id, nombre FROM almacenistas WHERE estado = 1";
            break;
        case 'unidades':
            $sql = "SELECT idunidad AS id, nombreunidad AS nombre FROM unidades";
            break;
        case 'precios':
            $sql = "SELECT idcliente, idproducto, idunidad, preciounitario FROM precios";
            break;
        case 'empresa':
            $table_check = $conn->query("SHOW TABLES LIKE 'empresas'");
            if ($table_check->num_rows == 0) {
                send_error("La tabla 'empresas' no existe en la base de datos.", 404);
            }
    
            $sql = "SELECT nombre, direccion, telefono FROM empresas LIMIT 1";
            $result = $conn->query($sql);
            
            if (!$result) {
                send_error("Error en la consulta SQL para 'empresas': " . $conn->error);
            }
            
            $data = $result->fetch_assoc();
            
            if ($data === null) {
                $data = (object)[]; 
            }
        
            send_response($data);
            break;
        case 'notas':
            $sql = "SELECT 
                        n.idnota,
                        n.idcliente,
                        n.total, 
                        n.saldo, 
                        n.regtimestamp, 
                        n.idalmacen,
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
                    WHERE n.estado = 1"; // Traer todas las notas activas
            break;
        case 'nota_detalles':
            $sql = "SELECT 
                        d.id AS iddetalle,
                        d.idnota AS idnota_fk,
                        d.idproducto,
                        d.idunidad,
                        d.cantidad,
                        d.precio,
                        d.total,
                        d.regtimestamp,
                        d.estado,
                        COALESCE(ed.idestatus, 1) AS idestatus, -- Provide default value
                        d.tipo_producto,
                        p.nombreproducto,
                        u.nombreunidad
                    FROM nota_detalle d
                    JOIN notas n ON d.idnota = n.idnota
                    JOIN productos p ON d.idproducto = p.idproducto
                    JOIN unidades u ON d.idunidad = u.idunidad
                    LEFT JOIN embarque_detalle ed ON n.idembarque = ed.idfolioembarque AND d.idproducto = ed.idproducto
                    WHERE n.estado = 1";
            break;
        case 'pagos':
             $sql = "SELECT 
                        p.id AS idpago,
                        p.idnota,
                        p.totalpago AS monto,
                        p.tipopago AS tipo_pago,
                        p.regtimestamp
                    FROM pagos_m p
                    JOIN notas n ON p.idnota = n.idnota
                    WHERE n.estado = 1 AND p.estado = 1";
            break;
        default:
            send_error("Entidad '{$entity}' no reconocida.", 400);
            break;
    }

    $result = $conn->query($sql);
    if (!$result) {
        throw new Exception($conn->error);
    }

    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }

    send_response($data);

} catch (Exception $e) {
    send_error('Error en la consulta: ' . $e->getMessage());
}
?>