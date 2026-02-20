<?php
function handleVendedores($conn, $method, $id) {
    global $conn;
    
    if ($conn instanceof PDO) {
        if ($method === 'GET') {
            if ($id) {
                $stmt = $conn->prepare("SELECT * FROM vendedores WHERE id = ?");
                $stmt->execute([$id]);
                $row = $stmt->fetch(PDO::FETCH_ASSOC);
                echo json_encode($row ?: null);
            } else {
                $stmt = $conn->query("SELECT * FROM vendedores ORDER BY nombre");
                $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
                echo json_encode($rows);
            }
        } elseif ($method === 'POST') {
            $d = getJsonInput();
            $stmt = $conn->prepare("INSERT INTO vendedores (id,nombre,codigo,zona,coachId,geolocalizacionActiva,horaInicioJornada,presupuestoMensual,presupuestoDiario) VALUES (?,?,?,?,?,?,?,?,?)");
            $stmt->execute([
                $d['id'] ?? uniqid('v_'),
                $d['nombre'], $d['codigo'], $d['zona'], $d['coachId'],
                $d['geolocalizacionActiva'] ?? 0,
                $d['horaInicioJornada'] ?? null,
                $d['presupuestoMensual'] ?? 0,
                $d['presupuestoDiario'] ?? 0
            ]);
            echo json_encode(['success' => true, 'id' => $d['id'] ?? '']);
        } elseif ($method === 'DELETE' && $id) {
            $stmt = $conn->prepare("DELETE FROM vendedores WHERE id = ?");
            $stmt->execute([$id]);
            echo json_encode(['success' => true]);
        }
    } else {
        if ($method === 'GET') {
            if ($id) {
                $stmt = sqlsrv_query($conn, "SELECT * FROM vendedores WHERE id = ?", [$id]);
                $row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC);
                sqlsrv_free_stmt($stmt);
                echo json_encode($row ?: null);
            } else {
                $stmt = sqlsrv_query($conn, "SELECT * FROM vendedores ORDER BY nombre");
                $rows = [];
                while ($r = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC)) $rows[] = $r;
                sqlsrv_free_stmt($stmt);
                echo json_encode($rows);
            }
        } elseif ($method === 'POST') {
            $d = getJsonInput();
            $id = $d['id'] ?? uniqid('v_');
            $sql = "INSERT INTO vendedores (id,nombre,codigo,zona,coachId,geolocalizacionActiva,horaInicioJornada,presupuestoMensual,presupuestoDiario) VALUES (?,?,?,?,?,?,?,?,?)";
            $params = [$id, $d['nombre'], $d['codigo'], $d['zona'], $d['coachId'], $d['geolocalizacionActiva'] ?? 0, $d['horaInicioJornada'] ?? null, $d['presupuestoMensual'] ?? 0, $d['presupuestoDiario'] ?? 0];
            $stmt = sqlsrv_query($conn, $sql, $params);
            if ($stmt === false) {
                http_response_code(500);
                echo json_encode(['error' => print_r(sqlsrv_errors(), true)]);
                exit;
            }
            sqlsrv_free_stmt($stmt);
            echo json_encode(['success' => true, 'id' => $id]);
        } elseif ($method === 'DELETE' && $id) {
            $stmt = sqlsrv_query($conn, "DELETE FROM vendedores WHERE id = ?", [$id]);
            if ($stmt === false) {
                http_response_code(500);
                echo json_encode(['error' => print_r(sqlsrv_errors(), true)]);
                exit;
            }
            sqlsrv_free_stmt($stmt);
            echo json_encode(['success' => true]);
        }
    }
}
