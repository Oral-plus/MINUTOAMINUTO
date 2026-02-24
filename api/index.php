<?php
declare(strict_types=1);

require_once __DIR__ . '/core/http.php';
require_once __DIR__ . '/config/database.php';

sendApiHeaders();

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    jsonResponse(['success' => true], 200);
    exit;
}

$segments = resolveRouteSegments();
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {
    $conn = getDbConnection();

    if (empty($segments)) {
        jsonResponse([
            'success' => true,
            'api' => 'Minuto a Minuto',
            'version' => '2.0',
            'time' => date('c'),
        ]);
        exit;
    }

    $resource = $segments[0];
    $id = $segments[1] ?? null;

    switch ($resource) {
        case 'test':
        case 'health':
            if (($segments[1] ?? 'db') !== 'db' && $resource === 'health') {
                jsonResponse(['success' => true, 'resource' => 'health']);
            } else {
                $db = testDatabaseConnection();
                jsonResponse($db, $db['success'] ? 200 : 500);
            }
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
        case 'audio':
            require __DIR__ . '/endpoints/audio.php';
            handleAudio($conn, $method, $id);
            break;
        default:
            jsonResponse(['success' => false, 'error' => 'Recurso no encontrado'], 404);
    }
} catch (InvalidArgumentException $e) {
    jsonResponse(['success' => false, 'error' => $e->getMessage()], 400);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'error' => APP_DEBUG ? $e->getMessage() : 'Error interno del servidor.',
    ], 500);
}
