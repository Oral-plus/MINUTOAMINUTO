<?php
function handleAlertas($conn, $method, $id) {
    if ($method === 'GET') {
        $resueltas = isset($_GET['resuelta']) ? (int)$_GET['resuelta'] : 0;
        $sql = "SELECT * FROM alertas WHERE resuelta = ? ORDER BY fecha DESC";
        
        if ($conn instanceof PDO) {
            $stmt = $conn->prepare($sql);
            $stmt->execute([$resueltas]);
            echo json_encode($stmt->fetchAll(PDO::FETCH_ASSOC));
        } else {
            $stmt = sqlsrv_query($conn, $sql, [$resueltas]);
            $rows = [];
            while ($r = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC)) {
                if (isset($r['fecha']) && $r['fecha'] instanceof DateTime) $r['fecha'] = $r['fecha']->format('Y-m-d\TH:i:s');
                $rows[] = $r;
            }
            sqlsrv_free_stmt($stmt);
            echo json_encode($rows);
        }
    } elseif ($method === 'POST') {
        $d = getJsonInput();
        $aid = $d['id'] ?? uniqid('alerta_');
        $sql = "INSERT INTO alertas (id,tipo,fecha,mensaje,vendedorId,supervisorId,zona,resuelta) VALUES (?,?,?,?,?,?,?,?)";
        $params = [$aid, $d['tipo'], $d['fecha'], $d['mensaje'], $d['vendedorId'] ?? null, $d['supervisorId'] ?? null, $d['zona'] ?? '', (int)($d['resuelta'] ?? 0)];
        if ($conn instanceof PDO) $conn->prepare($sql)->execute($params);
        else sqlsrv_query($conn, $sql, $params);
        echo json_encode(['success' => true]);
    }
}
