<?php
function handlePpvc($conn, $method, $id) {
    if ($method === 'GET') {
        $fecha = $_GET['fecha'] ?? date('Y-m-d');
        $vendedorId = $_GET['vendedorId'] ?? null;
        
        if ($vendedorId) {
            $sql = "SELECT * FROM ppvc WHERE vendedorId = ? AND fecha = ?";
            $params = [$vendedorId, $fecha];
        } else {
            $sql = "SELECT * FROM ppvc WHERE fecha = ?";
            $params = [$fecha];
        }
        
        if ($conn instanceof PDO) {
            $stmt = $conn->prepare($sql);
            $stmt->execute($params);
            $row = $vendedorId ? $stmt->fetch(PDO::FETCH_ASSOC) : $stmt->fetchAll(PDO::FETCH_ASSOC);
            echo json_encode($row ?: ($vendedorId ? null : []));
        } else {
            $stmt = sqlsrv_query($conn, $sql, $params);
            $rows = [];
            while ($r = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC)) {
                if (isset($r['fecha']) && $r['fecha'] instanceof DateTime) $r['fecha'] = $r['fecha']->format('Y-m-d');
                $rows[] = $r;
            }
            sqlsrv_free_stmt($stmt);
            echo json_encode($vendedorId ? ($rows[0] ?? null) : $rows);
        }
    } elseif ($method === 'POST') {
        $d = getJsonInput();
        $pid = $d['id'] ?? uniqid('ppvc_');
        $sql = "INSERT INTO ppvc (id,vendedorId,fecha,zona,clientesProgramados,clientes60Ids,clientesPerdidosIds,metaVenta,metaRecaudo,programado2DiasAntes) VALUES (?,?,?,?,?,?,?,?,?,?)";
        $params = [$pid, $d['vendedorId'], $d['fecha'], $d['zona'] ?? '', (int)($d['clientesProgramados'] ?? 0), $d['clientes60Ids'] ?? '', $d['clientesPerdidosIds'] ?? '', (float)($d['metaVenta'] ?? 0), (float)($d['metaRecaudo'] ?? 0), (int)($d['programado2DiasAntes'] ?? 0)];
        if ($conn instanceof PDO) {
            $conn->prepare($sql)->execute($params);
        } else {
            sqlsrv_query($conn, $sql, $params);
        }
        echo json_encode(['success' => true, 'id' => $pid]);
    }
}
