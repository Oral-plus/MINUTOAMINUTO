<?php
function handleLlamadas($conn, $method, $id) {
    if ($method === 'GET') {
        $desde = $_GET['desde'] ?? date('Y-m-d');
        $hasta = $_GET['hasta'] ?? date('Y-m-d');
        $zona = $_GET['zona'] ?? null;
        $contactado = $_GET['nombreContactado'] ?? null;
        
        $sql = "SELECT * FROM registro_llamadas WHERE fecha >= ? AND fecha <= ?";
        $params = [$desde, $hasta];
        if ($zona) { $sql .= " AND zona = ?"; $params[] = $zona; }
        if ($contactado) { $sql .= " AND nombreContactado = ?"; $params[] = $contactado; }
        $sql .= " ORDER BY horaInicio DESC";
        
        if ($conn instanceof PDO) {
            $stmt = $conn->prepare($sql);
            $stmt->execute($params);
            echo json_encode($stmt->fetchAll(PDO::FETCH_ASSOC));
        } else {
            $stmt = sqlsrv_query($conn, $sql, $params);
            $rows = [];
            while ($r = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC)) {
                if (isset($r['fecha']) && $r['fecha'] instanceof DateTime) $r['fecha'] = $r['fecha']->format('Y-m-d');
                if (isset($r['horaInicio']) && $r['horaInicio'] instanceof DateTime) $r['horaInicio'] = $r['horaInicio']->format('Y-m-d H:i:s');
                if (isset($r['horaFin']) && $r['horaFin'] instanceof DateTime) $r['horaFin'] = $r['horaFin']->format('Y-m-d H:i:s');
                $rows[] = $r;
            }
            sqlsrv_free_stmt($stmt);
            echo json_encode($rows);
        }
    } elseif ($method === 'POST') {
        $d = getJsonInput();
        $rid = $d['id'] ?? uniqid('llamada_');
        $sql = "INSERT INTO registro_llamadas (id,fecha,horaInicio,horaFin,duracionMinutos,tipoLlamada,cargoLider,zona,nombreLider,nombreContactado,clientesProgramados,clientesVisitados,ventaDia,recaudoDia,cumplioMeta,coincidenciaPpvcRvc,conversion60,recuperacionPerdidos,observaciones,confirmacionVeracidad,rutaGrabacion,transcripcionTexto) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
        $params = [
            $rid, $d['fecha'], $d['horaInicio'], $d['horaFin'], (int)$d['duracionMinutos'],
            $d['tipoLlamada'], $d['cargoLider'], $d['zona'], $d['nombreLider'], $d['nombreContactado'],
            (int)($d['clientesProgramados'] ?? 0), (int)($d['clientesVisitados'] ?? 0),
            (float)($d['ventaDia'] ?? 0), (float)($d['recaudoDia'] ?? 0),
            (int)($d['cumplioMeta'] ?? 0), (int)($d['coincidenciaPpvcRvc'] ?? 0),
            (int)($d['conversion60'] ?? 0), (int)($d['recuperacionPerdidos'] ?? 0),
            $d['observaciones'] ?? '', (int)($d['confirmacionVeracidad'] ?? 0),
            $d['rutaGrabacion'] ?? null, $d['transcripcionTexto'] ?? null
        ];
        if ($conn instanceof PDO) {
            $conn->prepare($sql)->execute($params);
        } else {
            sqlsrv_query($conn, $sql, $params);
        }
        echo json_encode(['success' => true, 'id' => $rid]);
    }
}
