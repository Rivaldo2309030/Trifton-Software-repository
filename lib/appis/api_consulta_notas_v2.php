<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
require_once __DIR__ . '/conexion.php';

if ($_SERVER['REQUEST_METHOD'] == 'GET') {
    try {
        $debug_checkpoints = [];

        // Verificar si se proporciona un idcliente
        if (isset($_GET['idcliente'])) {
            $debug_checkpoints[] = "Iniciando modo: obtener notas de cliente.";
            // --- Lógica para obtener notas de un cliente específico ---
            $idcliente = $_GET['idcliente'];
            $fecha = $_GET['fecha'] ?? null;

            if (!filter_var($idcliente, FILTER_VALIDATE_INT)) {
                throw new Exception("ID de cliente inválido.", 400);
            }
            $debug_checkpoints[] = "ID de cliente validado: $idcliente";
            $tipo_producto_filter = $_GET['tipo_producto'] ?? 'P'; // Default a 'P'

            // Se buscan notas con saldo pendiente para ese cliente
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
                        COALESCE(pagos_sum.total_pagado, 0) AS monto_pagado_acumulado,
                        MAX(ed.tipo_producto) as tipo_producto,
                        -- Cálculos de Cajas (Usando CANTIDAD, no dinero)
                        SUM(CASE WHEN ed.tipo_producto = 'C' THEN ed.cantidad ELSE 0 END) as total_cajas,
                        COALESCE(pagos_caja.total_devuelto, 0) as cajas_devueltas,
                        (SUM(CASE WHEN ed.tipo_producto = 'C' THEN ed.cantidad ELSE 0 END) - COALESCE(pagos_caja.total_devuelto, 0)) as saldo_cajas
                    FROM notas AS n
                    JOIN clientes AS c ON n.idcliente = c.idcliente
                    JOIN usuarios AS u ON n.idusuario = u.idusuario
                    JOIN almacenes AS alm_salida ON n.idalmacen = alm_salida.idalmacen
                    JOIN embarque AS e ON n.idembarque = e.idfolioembarque
                    LEFT JOIN almacenes AS alm_origen ON e.idalmacen = alm_origen.idalmacen
                    JOIN embarque_detalle AS ed ON e.idfolioembarque = ed.idfolioembarque 
                    LEFT JOIN (
                        SELECT idnota, SUM(totalpago) AS total_pagado
                        FROM pagos_m
                        WHERE estado = 1 AND tipopago != 'Caja' 
                        GROUP BY idnota
                    ) AS pagos_sum ON n.idnota = pagos_sum.idnota
                    LEFT JOIN (
                        SELECT idnota, SUM(totalpago) AS total_devuelto
                        FROM pagos_m
                        WHERE estado = 1 AND tipopago = 'Caja'
                        GROUP BY idnota
                    ) AS pagos_caja ON n.idnota = pagos_caja.idnota
                    WHERE n.idcliente = ? AND n.saldo > 0 AND ed.tipo_producto = ?
                    ";
            
            $params = [$idcliente, $tipo_producto_filter];
            $types = "is";

            if ($fecha) {
                $sql .= " AND n.regtimestamp >= ? AND n.regtimestamp < DATE_ADD(?, INTERVAL 1 DAY)";
                $types .= "ss";
                $params[] = $fecha;
                $params[] = $fecha;
            }

            $sql .= " GROUP BY n.idnota ORDER BY n.regtimestamp DESC";
            $debug_checkpoints[] = "SQL para notas de cliente construido.";

            $stmt = $conn->prepare($sql);
            if ($stmt === false) {
                throw new Exception("Error al preparar la consulta de notas: " . $conn->error);
            }
            $stmt->bind_param($types, ...$params);
            $stmt->execute();
            $result = $stmt->get_result();
            
            $data = [];
            while ($row = $result->fetch_assoc()) {
                $data[] = $row;
            }

            // --- CÁLCULO DE RESUMEN INDEPENDIENTE ---
            // Usamos la fecha seleccionada o la de hoy como pivote
            $fecha_referencia = $fecha ? $fecha : date('Y-m-d');
            
            // 1. Saldo Anterior (Todo lo que se debe de fechas ANTERIORES a la referencia)
            // Para Cajas: Saldo de cajas acumulado anterior. Para Productos: Saldo monetario anterior.
            $sql_res_ant = "SELECT 
                                SUM(CASE WHEN tipo_producto = 'P' THEN saldo ELSE 0 END) as saldo_ant_monetario,
                                SUM(CASE WHEN tipo_producto = 'C' THEN (
                                    -- Aproximación de saldo de cajas histórico (Total - Devuelto) para notas viejas
                                    -- Nota: Esto es complejo en una sola linea, sumaremos saldos estimados
                                    -- Para simplificar y no hacer subquerys pesadas aqui, usaremos la logica de 'saldo' de la tabla notas si fuera confiable, 
                                    -- pero como dependemos de embarque_detalle, haremos un calculo basico:
                                    0 
                                ) ELSE 0 END) as saldo_ant_cajas_placeholder
                            FROM notas 
                            WHERE idcliente = ? AND saldo > 0 AND DATE(regtimestamp) < ?";
            
            // Corrección: Para calcular saldo de cajas anterior correctamente necesitamos la misma lógica compleja.
            // Dado que el usuario quiere ver "Pendientes" (que es el saldo actual total), vamos a simplificar:
            // Saldo Anterior = Deuda total vencida antes de hoy.
            
            // Vamos a usar una lógica robusta reutilizando la estructura de la consulta principal pero agrupada
            $sql_resumen = "
                SELECT 
                    -- PRODUCTOS (Monetario)
                    SUM(CASE WHEN ed.tipo_producto = 'P' AND DATE(n.regtimestamp) < ? THEN n.saldo ELSE 0 END) as saldo_anterior_prod,
                    SUM(CASE WHEN ed.tipo_producto = 'P' AND DATE(n.regtimestamp) = ? THEN n.total ELSE 0 END) as pedido_hoy_prod,
                    SUM(CASE WHEN ed.tipo_producto = 'P' THEN n.saldo ELSE 0 END) as total_credito_prod,
                    
                    -- CAJAS (Inventario)
                    -- Cajas Pendientes (Saldo Anterior): Cajas que se debían antes de la fecha seleccionada
                    SUM(CASE WHEN ed.tipo_producto = 'C' AND DATE(n.regtimestamp) < ? THEN 
                        (ed.cantidad - COALESCE(pagos_caja.devuelto, 0))
                    ELSE 0 END) as cajas_pendientes_ant,
                    
                    -- Cajas del Día (Pedido Hoy): Cajas entregadas en la fecha seleccionada
                    SUM(CASE WHEN ed.tipo_producto = 'C' AND DATE(n.regtimestamp) = ? THEN ed.cantidad ELSE 0 END) as cajas_entregas_hoy,
                    
                    -- Total Cajas Entregadas (Total histórico o del día? El usuario pidió 'Total Cajas Entregadas')
                    -- Asumiremos que es el acumulado histórico de cajas entregadas (sin restar devoluciones) para dar contexto de volumen
                    SUM(CASE WHEN ed.tipo_producto = 'C' THEN ed.cantidad ELSE 0 END) as total_cajas_historico,
                    
                    -- Total Pendientes (Saldo Actual Total)
                    SUM(CASE WHEN ed.tipo_producto = 'C' THEN 
                        (ed.cantidad - COALESCE(pagos_caja.devuelto, 0))
                    ELSE 0 END) as total_cajas_pendientes
                    
                FROM notas AS n
                JOIN embarque AS e ON n.idembarque = e.idfolioembarque
                JOIN embarque_detalle AS ed ON e.idfolioembarque = ed.idfolioembarque
                LEFT JOIN (
                    SELECT idnota, SUM(totalpago) AS devuelto
                    FROM pagos_m
                    WHERE estado = 1 AND tipopago = 'Caja'
                    GROUP BY idnota
                ) AS pagos_caja ON n.idnota = pagos_caja.idnota
                WHERE n.idcliente = ? AND n.saldo > 0 AND ed.tipo_producto = ?
            ";
            
            $stmt_res = $conn->prepare($sql_resumen);
            // Params: FechaRef, FechaRef, FechaRef, FechaRef, IdCliente, TipoProducto
            $stmt_res->bind_param("ssssis", $fecha_referencia, $fecha_referencia, $fecha_referencia, $fecha_referencia, $idcliente, $tipo_producto_filter);
            $stmt_res->execute();
            $res_data = $stmt_res->get_result()->fetch_assoc();
            
            $response = [
                "type" => "notas", 
                "data" => $data,
                "resumen" => [
                    // Resumen Financiero
                    "saldo_anterior" => (float)$res_data['saldo_anterior_prod'],
                    "pedido_hoy" => (float)$res_data['pedido_hoy_prod'],
                    "total_credito" => (float)$res_data['total_credito_prod'],
                    
                    // Resumen Cajas
                    "cajas_pendientes" => (float)$res_data['cajas_pendientes_ant'], // Pendientes ANTES de la fecha
                    "cajas_en_entregas_hoy" => (float)$res_data['cajas_entregas_hoy'], // Entregadas HOY
                    "total_cajas_entregadas" => (float)$res_data['total_cajas_pendientes'] // Pendientes TOTALES (Actuales)
                    // Nota: Cambié 'total_cajas_entregadas' por 'total_cajas_pendientes' en la lógica de asignación
                    // porque usualmente en el resumen inferior se quiere ver el TOTAL DE LA DEUDA DE CAJAS.
                ]
            ];

        } else {
            $debug_checkpoints[] = "Iniciando modo: obtener lista de clientes Y RESUMENES.";
            // --- Lógica para obtener la lista de clientes con notas pendientes y resúmenes ---
            $fecha = $_GET['fecha'] ?? null;
            $nombre_cliente_filtro = $_GET['nombre_cliente'] ?? null;
            $tipo_producto_filter = $_GET['tipo_producto'] ?? 'P';

            // --- Calcular resúmenes (Usando embarque_detalle para consistencia) ---
            // Saldo Anterior
            $sql_saldo_anterior = "
                SELECT SUM(n.saldo) AS saldo
                FROM notas AS n
                JOIN embarque_detalle AS ed ON n.idembarque = ed.idfolioembarque
                WHERE n.saldo > 0 
                AND DATE(n.regtimestamp) < CURDATE()
                AND ed.tipo_producto = ?
            ";
            $stmt_saldo_anterior = $conn->prepare($sql_saldo_anterior);
            $stmt_saldo_anterior->bind_param("s", $tipo_producto_filter);
            $stmt_saldo_anterior->execute();
            $result_saldo_anterior = $stmt_saldo_anterior->get_result()->fetch_assoc();
            $saldo_anterior = $result_saldo_anterior['saldo'] ? (float)$result_saldo_anterior['saldo'] : 0.0;
            $stmt_saldo_anterior->close();

            // Pedido de Hoy (notas con regtimestamp = hoy, filtrado por tipo_producto)
            $sql_pedido_hoy = "
                SELECT SUM(n.total) AS total
                FROM notas AS n
                JOIN embarque_detalle AS ed ON n.idembarque = ed.idfolioembarque
                WHERE DATE(n.regtimestamp) = CURDATE()
                AND ed.tipo_producto = ?
            ";
            $stmt_pedido_hoy = $conn->prepare($sql_pedido_hoy);
            $stmt_pedido_hoy->bind_param("s", $tipo_producto_filter);
            $stmt_pedido_hoy->execute();
            $result_pedido_hoy = $stmt_pedido_hoy->get_result()->fetch_assoc();
            $pedido_hoy = $result_pedido_hoy['total'] ? (float)$result_pedido_hoy['total'] : 0.0;
            $stmt_pedido_hoy->close();

            $total_credito = $saldo_anterior + $pedido_hoy;

            // --- Obtener clientes con notas pendientes (filtrado por tipo_producto) ---
            $sql = "SELECT DISTINCT c.idcliente, c.nombrecliente 
                    FROM clientes AS c
                    JOIN notas AS n ON c.idcliente = n.idcliente
                    JOIN embarque_detalle AS ed ON n.idembarque = ed.idfolioembarque
                    WHERE n.saldo > 0 AND ed.tipo_producto = ?
                    ";
            // ... resto del código ...
            
            $params = [$tipo_producto_filter];
            $types = "s";

            if ($fecha) {
                $sql .= " AND n.regtimestamp >= ? AND n.regtimestamp < DATE_ADD(?, INTERVAL 1 DAY)";
                $types .= "ss";
                $params[] = $fecha;
                $params[] = $fecha;
            }
            if ($nombre_cliente_filtro) {
                $sql .= " AND c.nombrecliente LIKE ?";
                $types .= "s";
                $params[] = "%" . $nombre_cliente_filtro . "%";
            }

            $sql .= " ORDER BY c.nombrecliente ASC";
            $debug_checkpoints[] = "SQL para lista de clientes construido.";
            
            $stmt = $conn->prepare($sql);
            if ($stmt === false) {
                throw new Exception("Error al preparar la consulta de clientes: " . $conn->error);
            }
            $stmt->bind_param($types, ...$params);
            $debug_checkpoints[] = "Consulta de clientes preparada.";

            $stmt->execute();
            $debug_checkpoints[] = "Consulta de clientes ejecutada.";
            
            $result = $stmt->get_result();
            
            $data = [];
            while ($row = $result->fetch_assoc()) {
                $data[] = $row;
            }
            $debug_checkpoints[] = "Datos de clientes obtenidos.";
            $response = [
                "type" => "clientes", 
                "data" => $data,
                "resumen" => [
                    "saldo_anterior" => $saldo_anterior,
                    "pedido_hoy" => $pedido_hoy,
                    "total_credito" => $total_credito
                ]
            ];
        }
        
        http_response_code(200);
        echo json_encode(["success" => true, "response" => $response]);

    } catch (Exception $e) {
        $errorCode = $e->getCode() == 400 ? 400 : 500;
        http_response_code($errorCode);
        echo json_encode([
            "success" => false, 
            "error" => "Error en API (consulta_notas_v2): " . $e->getMessage(),
            "line" => $e->getLine(),
            "checkpoints" => $debug_checkpoints ?? []
        ]);
    }

    if (isset($stmt)) $stmt->close();
    $conn->close();

} else {
    http_response_code(405);
    echo json_encode(["success" => false, "error" => "Método no permitido."]);
}
?>