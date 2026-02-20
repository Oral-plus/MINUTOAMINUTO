<?php
function handleUbicaciones($conn, $method, $id) {
    if ($method === 'POST') {
        $d = getJsonInput();
        $uid = $d['id'] ?? uniqid('ub_');
        $sql = "INSERT INTO ubicaciones (id,vendedorId,fecha,latitud,longitud,[timestamp]) VALUES (?,?,?,?,?,?)";
        $params = [$uid, $d['vendedorId'], $d['fecha'] ?? date('Y-m-d'), (float)$d['latitud'], (float)$d['longitud'], $d['timestamp'] ?? date('Y-m-d H:i:s')];
        if ($conn instanceof PDO) $conn->prepare($sql)->execute($params);
        else sqlsrv_query($conn, $sql, $params);
        echo json_encode(['success' => true]);
    }
}
