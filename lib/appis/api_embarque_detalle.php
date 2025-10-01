<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

$servername = "srv571.hstgr.io";
$username = "u203835291_serviceOrder";
$password = "TritonSrv2025$%";
$dbname = "u203835291_orders";

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    http_response_code(500);
    die(json_encode(["error" => "Connection failed: " . $conn->connect_error]));
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'POST') {
    try {
        $input = json_decode(file_get_contents("php://input"), true);

        if (!$input || !isset($input['idembarque']) || !isset($input['productos'])) {
            http_response_code(400);
            echo json_encode(["error" => "JSON inválido o datos incompletos"]);
            exit;
        }

        $idembarque = $input['idembarque'];
        $productos = $input['productos'];
        
        $total_insertados = 0;
        $errores = [];

        $stmt = $conn->prepare("INSERT INTO embarque_detalle (idembarque, idproducto, cantidad, precio_unitario) VALUES (?, ?, ?, ?)");

        $idproducto = null;
        $cantidad = null;
        $precio = null;

        $stmt->bind_param("iiid", $idembarque, $idproducto, $cantidad, $precio);

        foreach ($productos as $producto) {
            $idproducto = $producto['idproducto'];
            $cantidad = $producto['cantidad'];
            $precio = $producto['precio'];

            if (!$stmt->execute()) {
                $errores[] = ["error" => $stmt->error, "producto" => $producto];
            }
        }

        $stmt->close();
        
        if (count($errores) > 0) {
            http_response_code(500);
            echo json_encode(["success" => false, "message" => "Ocurrieron errores al guardar algunos productos", "errores" => $errores]);
        } else {
            http_response_code(201);
            echo json_encode(["success" => true, "message" => "Detalles del embarque guardados correctamente"]);
        }

    } catch (mysqli_sql_exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "error" => "Error SQL: " . $e->getMessage()]);
    }

} else {
    http_response_code(405);
    echo json_encode(["error" => "Método no permitido. Solo se acepta POST."]);
}

$conn->close();
?>