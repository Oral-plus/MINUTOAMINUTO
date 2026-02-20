<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/config/database.php';

$requestUri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$path = preg_replace('#^.*/(api/|api\.php/?)#', '', $requestUri);
$path = str_replace('index.php/', '', $path);
$path = trim($path, '/');
$segments = $path ? explode('/', $path) : [];
$method = $_SERVER['REQUEST_METHOD'];

try {
    $conn = getDbConnection();
    
    if (empty($segments[0])) {
        echo json_encode(['status' => 'ok', 'api' => 'Minuto a Minuto', 'version' => '1.0']);
        exit;
    }
    
    $resource = $segments[0];
    $id = $segments[1] ?? null;
    
    switch ($resource) {
        case 'test':
            echo json_encode(testDatabaseConnection());
            break;
        case 'vendedores':
            require __DIR__ . '/endpoints/vendedores.php';
            handleVendedores($conn, $method, $id);
            break;
        case 'supervisores':
            require __DIR__ . '/endpoints/supervisores.php';
            handleSupervisores($conn, $method, $id);
            break;
        case 'llamadas':
            require __DIR__ . '/endpoints/llamadas.php';
            handleLlamadas($conn, $method, $id);
            break;
        case 'ppvc':
            require __DIR__ . '/endpoints/ppvc.php';
            handlePpvc($conn, $method, $id);
            break;
        case 'rvc':
            require __DIR__ . '/endpoints/rvc.php';
            handleRvc($conn, $method, $id);
            break;
        case 'alertas':
            require __DIR__ . '/endpoints/alertas.php';
            handleAlertas($conn, $method, $id);
            break;
        case 'ubicaciones':
            require __DIR__ . '/endpoints/ubicaciones.php';
            handleUbicaciones($conn, $method, $id);
            break;
        default:
            http_response_code(404);
            echo json_encode(['error' => 'Recurso no encontrado']);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}

function getJsonInput() {
    $input = file_get_contents('php://input');
    return $input ? json_decode($input, true) : [];
}
