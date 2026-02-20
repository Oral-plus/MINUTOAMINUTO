<?php
function handleRvc($conn, $method, $id) {
    if ($method === 'GET') {
        $fecha = $_GET['fecha'] ?? date('Y-m-d');
        $vendedorId = $_GET['vendedorId'] ?? null;
        
        if ($vendedorId) {
            $sql = "SELECT * FROM rvc WHERE vendedorId = ? AND fecha = ?";
            $params = [$vendedorId, $fecha];
        } else {
            $sql = "SELECT * FROM rvc WHERE fecha = ?";
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
        $rid = $d['id'] ?? uniqid('rvc_');
        $sql = "INSERT INTO rvc (id,vendedorId,fecha,zona,clientesVisitados,clientes60Visitados,clientesPerdidosVisitados,ventaTotal,recaudoTotal,clientesNoVisitados,descuentosAplicados) VALUES (?,?,?,?,?,?,?,?,?,?,?)";
        $params = [$rid, $d['vendedorId'], $d['fecha'], $d['zona'] ?? '', (int)($d['clientesVisitados'] ?? 0), (int)($d['clientes60Visitados'] ?? 0), (int)($d['clientesPerdidosVisitados'] ?? 0), (float)($d['ventaTotal'] ?? 0), (float)($d['recaudoTotal'] ?? 0), $d['clientesNoVisitados'] ?? '', (int)($d['descuentosAplicados'] ?? 0)];
        if ($conn instanceof PDO) $conn->prepare($sql)->execute($params);
        else sqlsrv_query($conn, $sql, $params);
        echo json_encode(['success' => true, 'id' => $rid]);
    }
}
