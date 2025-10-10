<?php
require_once __DIR__ . '/conexion.php';

// Habilitar reporte de errores para depuración
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

if ($_SERVER['REQUEST_METHOD'] == 'GET') {
    try {
        // Por ahora, no hay filtros. Se añadirán después.
        // $filtro_cliente = $_GET['cliente'] ?? null;
        // $filtro_producto = $_GET['producto'] ?? null;

        $sql = "SELECT 
                    ed.iddetalle AS id_detalle,
                    ed.cantidad,
                    ed.preciounitario AS precio_unitario,
                    p.nombreproducto,
                    u.nombreunidad,
                    c.nombrecliente,
                    e.regtimestamp AS fecha_embarque
                FROM embarque_detalle AS ed
                JOIN embarque AS e ON ed.idfolioembarque = e.idfolioembarque
                JOIN productos AS p ON ed.idproducto = p.idproducto
                JOIN unidades AS u ON ed.idunidad = u.idunidad
                JOIN clientes AS c ON e.idcliente = c.idcliente
                ORDER BY e.regtimestamp DESC
                LIMIT 100"; // Limitar a 100 resultados por ahora

        $stmt = $conn->prepare($sql);
        $stmt->execute();
        $result = $stmt->get_result();
        $historial = [];
        while ($row = $result->fetch_assoc()) {
            $historial[] = $row;
        }
        
        http_response_code(200);
        echo json_encode(["success" => true, "data" => $historial]);

    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "error" => $e->getMessage()]);
    }

    if (isset($stmt)) $stmt->close();
    $conn->close();

} else {
    http_response_code(405);
    echo json_encode(["success" => false, "error" => "Método no permitido."]);
}
?>
