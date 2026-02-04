<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
require_once __DIR__ . '/conexion.php';

if ($_SERVER['REQUEST_METHOD'] == 'GET') {
    try {
        $idcliente = isset($_GET['idcliente']) ? (int)$_GET['idcliente'] : null;
        $fecha = isset($_GET['fecha']) ? $_GET['fecha'] : date('Y-m-d'); // Fecha seleccionada o Hoy

        // --- Resumen de Cajas ---
        
        // 1. Cajas Pendientes (Saldo Anterior / Pendiente Actual)
        // Si se consulta una fecha específica, queremos ver qué se debía ANTES de ese día (Saldo Anterior).
        // Si es hoy, queremos ver lo que se debe actualmente.
        $sql_pendientes = "
            SELECT 
                SUM(ed.cantidad - COALESCE(pm.total_cajas_devueltas, 0)) AS cajas_pendientes
            FROM embarque_detalle ed
            JOIN notas n ON n.idembarque = ed.idfolioembarque
            LEFT JOIN (
                SELECT iddetalle_embarque, SUM(totalpago) AS total_cajas_devueltas
                FROM pagos_m
                WHERE tipopago = 'Caja'
                GROUP BY iddetalle_embarque
            ) pm ON pm.iddetalle_embarque = ed.iddetalle
            WHERE ed.tipo_producto = 'C' 
            AND (ed.cantidad - COALESCE(pm.total_cajas_devueltas, 0)) > 0
        ";
        
        // Filtro de fecha para "Saldo Anterior"
        // Si fecha param != hoy, filtramos notas < fecha. Si no, no filtramos (saldo total actual).
        $params_pend = [];
        $types_pend = "";
        
        if (isset($_GET['fecha'])) {
             $sql_pendientes .= " AND DATE(n.regtimestamp) < ?";
             $params_pend[] = $fecha;
             $types_pend .= "s";
        }

        if ($idcliente) {
            $sql_pendientes .= " AND n.idcliente = ?";
            $params_pend[] = $idcliente;
            $types_pend .= "i";
        }
        
        $stmt_pendientes = $conn->prepare($sql_pendientes);
        if (!empty($params_pend)) {
            $stmt_pendientes->bind_param($types_pend, ...$params_pend);
        }
        $stmt_pendientes->execute();
        $result_pendientes = $stmt_pendientes->get_result()->fetch_assoc();
        $cajas_pendientes = $result_pendientes['cajas_pendientes'] ? (float)$result_pendientes['cajas_pendientes'] : 0.0;
        $stmt_pendientes->close();

        // 2. Cajas en Entregas (Movimiento de la Fecha Seleccionada)
        $sql_entregas_hoy = "
            SELECT SUM(ed.cantidad) AS cajas_entregadas_hoy
            FROM embarque_detalle ed
            JOIN notas n ON ed.idfolioembarque = n.idembarque
            WHERE ed.tipo_producto = 'C'
            AND DATE(n.regtimestamp) = ?
        ";
        
        $params_hoy = [$fecha];
        $types_hoy = "s";

        if ($idcliente) {
            $sql_entregas_hoy .= " AND n.idcliente = ?";
            $params_hoy[] = $idcliente;
            $types_hoy .= "i";
        }
        
        $stmt_entregas_hoy = $conn->prepare($sql_entregas_hoy);
        $stmt_entregas_hoy->bind_param($types_hoy, ...$params_hoy);
        $stmt_entregas_hoy->execute();
        $result_entregas_hoy = $stmt_entregas_hoy->get_result()->fetch_assoc();
        $cajas_entregadas_hoy = $result_entregas_hoy['cajas_entregadas_hoy'] ? (float)$result_entregas_hoy['cajas_entregadas_hoy'] : 0.0;
        $stmt_entregas_hoy->close();

        // 3. Total de Cajas Entregadas (Acumulado Histórico) - Se mantiene igual
        $sql_total_entregadas = "
            SELECT SUM(pm.totalpago) AS total_cajas_entregadas
            FROM pagos_m pm
            JOIN notas n ON pm.idnota = n.idnota
            WHERE pm.tipopago = 'Caja'
        ";
        if ($idcliente) {
            $sql_total_entregadas .= " AND n.idcliente = ?";
        }
        $stmt_total_entregadas = $conn->prepare($sql_total_entregadas);
        if ($idcliente) {
            $stmt_total_entregadas->bind_param("i", $idcliente);
        }
        $stmt_total_entregadas->execute();
        $result_total_entregadas = $stmt_total_entregadas->get_result()->fetch_assoc();
        $total_cajas_entregadas = $result_total_entregadas['total_cajas_entregadas'] ? (float)$result_total_entregadas['total_cajas_entregadas'] : 0.0;
        $stmt_total_entregadas->close();

        $response = [
            "cajas_pendientes" => $cajas_pendientes,
            "cajas_en_entregas_hoy" => $cajas_entregadas_hoy,
            "total_cajas_entregadas" => $total_cajas_entregadas
        ];
        
        http_response_code(200);
        echo json_encode(["success" => true, "data" => $response]);

    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "error" => "Error en API (api_cajas_resumen): " . $e->getMessage()]);
    } finally {
        $conn->close();
    }

} else {
    http_response_code(405);
    echo json_encode(["success" => false, "error" => "Método no permitido."]);
}
?>
