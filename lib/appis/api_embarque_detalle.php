<?php
header('Content-Type: application/json');
require_once __DIR__ . '/conexion.php';

if ($_SERVER['REQUEST_METHOD'] == 'GET') {
    try {
        if (!isset($_GET['idfolioembarque'])) {
            throw new Exception("Se requiere el parámetro 'idfolioembarque'.", 400);
        }

        $idfolioembarque = $_GET['idfolioembarque'];

        if (!filter_var($idfolioembarque, FILTER_VALIDATE_INT)) {
            throw new Exception("El 'idfolioembarque' debe ser un número entero.", 400);
        }

        $sql = "SELECT 
                    ed.iddetalle, 
                    ed.cantidad, 
                    ed.preciounitario, 
                    ed.subtotal, 
                    ed.idestatus, 
                    ed.idproducto, 
                    ed.idunidad,
                    ed.tipo_producto,
                    p.nombreproducto, 
                    u.nombreunidad 
                FROM 
                    embarque_detalle ed 
                JOIN 
                    productos p ON ed.idproducto = p.idproducto 
                JOIN 
                    unidades u ON ed.idunidad = u.idunidad 
                WHERE 
                    ed.idfolioembarque = ?";

        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $idfolioembarque);
        $stmt->execute();
        $result = $stmt->get_result();

        $detalles = [];
        while ($row = $result->fetch_assoc()) {
            $detalles[] = $row;
        }
        
        http_response_code(200);
        echo json_encode(["success" => true, "data" => $detalles]);

    } catch (Exception $e) {
        $errorCode = $e->getCode() == 400 ? 400 : 500;
        http_response_code($errorCode);
        echo json_encode(["success" => false, "error" => $e->getMessage()]);
    }

    if (isset($stmt)) $stmt->close();
    $conn->close();

} else {
    http_response_code(405);
    echo json_encode(["success" => false, "error" => "Método no permitido."]);
}
?>