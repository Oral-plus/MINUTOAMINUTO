<?php
declare(strict_types=1);

function handleAudio($conn, string $method, ?string $id): void
{
    if ($method !== 'GET') {
        jsonResponse(['success' => false, 'error' => 'Método no permitido'], 405);
        return;
    }

    $llamadaId = isset($_GET['id']) ? trim((string)$_GET['id']) : ($id ?? '');
    if ($llamadaId === '') {
        jsonResponse(['success' => false, 'error' => 'id requerido'], 400);
        return;
    }

    $row = dbQueryOne($conn, 'SELECT rutaGrabacion FROM registro_llamadas WHERE id = ?', [$llamadaId]);
    if (!$row || empty($row['rutaGrabacion'])) {
        jsonResponse(['success' => false, 'error' => 'Audio no encontrado'], 404);
        return;
    }

    $ruta = trim((string)$row['rutaGrabacion']);
    if (startsWith($ruta, 'http://') || startsWith($ruta, 'https://')) {
        header('Location: ' . $ruta);
        exit;
    }

    $uploadsDir = realpath(__DIR__ . '/../uploads');
    if ($uploadsDir === false) {
        jsonResponse(['success' => false, 'error' => 'Directorio uploads no disponible'], 500);
        return;
    }

    $filePath = realpath($uploadsDir . DIRECTORY_SEPARATOR . basename($ruta));
    if (!$filePath || !startsWith($filePath, $uploadsDir) || !is_file($filePath)) {
        jsonResponse(['success' => false, 'error' => 'Archivo de audio no encontrado'], 404);
        return;
    }

    header_remove('Content-Type');
    header('Content-Type: audio/mpeg');
    header('Content-Length: ' . filesize($filePath));
    readfile($filePath);
    exit;
}
