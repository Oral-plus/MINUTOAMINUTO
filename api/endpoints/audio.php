<?php
/**
 * GET /audio?id=xxx - Sirve el archivo de audio de una llamada.
 * La rutaGrabacion puede ser: URL completa, o nombre de archivo en uploads/
 */
function handleAudio($conn, $method, $id) {
    if ($method !== 'GET') {
        http_response_code(405);
        echo json_encode(['error' => 'Método no permitido']);
        return;
    }
    $llamadaId = $_GET['id'] ?? $id;
    if (!$llamadaId) {
        http_response_code(400);
        echo json_encode(['error' => 'id requerido']);
        return;
    }
    $sql = "SELECT rutaGrabacion FROM registro_llamadas WHERE id = ?";
    $params = [$llamadaId];
    if ($conn instanceof PDO) {
        $stmt = $conn->prepare($sql);
        $stmt->execute($params);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
    } else {
        $stmt = sqlsrv_query($conn, $sql, $params);
        $row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC);
        sqlsrv_free_stmt($stmt);
    }
    if (!$row || empty($row['rutaGrabacion'])) {
        http_response_code(404);
        echo json_encode(['error' => 'Audio no encontrado']);
        return;
    }
    $ruta = trim($row['rutaGrabacion']);
    if (strpos($ruta, 'http://') === 0 || strpos($ruta, 'https://') === 0) {
        header('Location: ' . $ruta);
        exit;
    }
    $uploadsDir = __DIR__ . '/../uploads/';
    $filePath = realpath($uploadsDir . basename($ruta));
    if (!$filePath || strpos($filePath, realpath($uploadsDir)) !== 0) {
        http_response_code(404);
        echo json_encode(['error' => 'Archivo no encontrado']);
        return;
    }
    if (!is_file($filePath)) {
        http_response_code(404);
        echo json_encode(['error' => 'Archivo no existe']);
        return;
    }
    header('Content-Type: audio/mpeg');
    header('Content-Length: ' . filesize($filePath));
    readfile($filePath);
    exit;
}
