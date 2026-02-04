<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
require_once __DIR__ . '/conexion.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET' || !isset($_GET['idnota'])) {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "Método no permitido o falta idnota."]);
    exit();
}

try {
    $idnota = filter_var($_GET['idnota'], FILTER_VALIDATE_INT);
    if ($idnota === false) {
        throw new Exception("ID de nota inválido.");
    }

    $idunidad_caja = 1; // ID para 'CAJA'

    // 1. Obtener el ID del embarque asociado a la nota
    $stmt_embarque = $conn->prepare("SELECT idembarque FROM notas WHERE idnota = ?");
    if (!$stmt_embarque) throw new Exception("Error al preparar consulta de embarque: " . $conn->error);
    $stmt_embarque->bind_param("i", $idnota);
    $stmt_embarque->execute();
    $result_embarque = $stmt_embarque->get_result();
    $embarque_row = $result_embarque->fetch_assoc();
    $stmt_embarque->close();

    if (!$embarque_row) {
        throw new Exception("No se encontró la nota o no tiene un embarque asociado.");
    }
    $idembarque = $embarque_row['idembarque'];

    // 2. Obtener todos los productos de la nota que son 'Cajas'
    $stmt_items = $conn->prepare(
       "SELECT 
            ed.iddetalle, 
            ed.cantidad, 
            ed.preciounitario, 
            p.nombreproducto 
        FROM embarque_detalle ed
        JOIN productos p ON ed.idproducto = p.idproducto
        WHERE ed.idfolioembarque = ? AND ed.idunidad = ?"
    );
    if (!$stmt_items) throw new Exception("Error al preparar consulta de items: " . $conn->error);
    $stmt_items->bind_param("ii", $idembarque, $idunidad_caja);
    $stmt_items->execute();
    $result_items = $stmt_items->get_result();
    $items_caja = $result_items->fetch_all(MYSQLI_ASSOC);
    $stmt_items->close();

    $response_data = [];

    // 3. Para cada item, calcular cuántas cajas se han devuelto
    $stmt_devueltas = $conn->prepare(
        "SELECT SUM(totalpago) as total_devuelto 
         FROM pagos_m 
         WHERE idnota = ? AND tipopago = 'Caja' AND iddetalle_embarque = ? AND estado = 1"
    );
    if (!$stmt_devueltas) throw new Exception("Error al preparar consulta de devueltas: " . $conn->error);

    foreach ($items_caja as $item) {
        $iddetalle = $item['iddetalle'];
        $cantidad_original = (float)$item['cantidad'];
        
        $stmt_devueltas->bind_param("ii", $idnota, $iddetalle);
        $stmt_devueltas->execute();
        $result_devueltas = $stmt_devueltas->get_result();
        $row_devueltas = $result_devueltas->fetch_assoc();
        
        $cantidad_devuelta = (float)($row_devueltas['total_devuelto'] ?? 0);
        $saldo_item = $cantidad_original - $cantidad_devuelta;

        // Ya no filtramos por saldo > 0 para que la impresión siempre tenga datos
        $response_data[] = [
            "iddetalle_embarque" => $iddetalle,
            "nombre_producto" => $item['nombreproducto'],
            "precio_unitario" => (float)$item['preciounitario'],
            "cantidad_original" => $cantidad_original,
            "cantidad_devuelta" => $cantidad_devuelta,
            "saldo_cajas_item" => $saldo_item
        ];
    }
    $stmt_devueltas->close();

    http_response_code(200);
    echo json_encode(["success" => true, "data" => $response_data]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "error" => $e->getMessage()]);
} finally {
    $conn->close();
}
?>