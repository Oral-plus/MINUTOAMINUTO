<?php
function handleSupervisores($conn, $method, $id) {
    if ($conn instanceof PDO) {
        if ($method === 'GET') {
            if ($id) {
                $stmt = $conn->prepare("SELECT * FROM supervisores WHERE id = ?");
                $stmt->execute([$id]);
                $row = $stmt->fetch(PDO::FETCH_ASSOC);
                echo json_encode($row ?: null);
            } else {
                $stmt = $conn->query("SELECT * FROM supervisores ORDER BY nombre");
                echo json_encode($stmt->fetchAll(PDO::FETCH_ASSOC));
            }
        } elseif ($method === 'POST') {
            $d = getJsonInput();
            $subIds = isset($d['subordinadosIds']) ? (is_array($d['subordinadosIds']) ? implode(',', $d['subordinadosIds']) : $d['subordinadosIds']) : '';
            $stmt = $conn->prepare("INSERT INTO supervisores (id,nombre,codigo,zona,cargo,superiorId,subordinadosIds) VALUES (?,?,?,?,?,?,?)");
            $stmt->execute([
                $d['id'] ?? uniqid('s_'),
                $d['nombre'] ?? '', $d['codigo'] ?? '', $d['zona'] ?? '', $d['cargo'] ?? 'coach',
                $d['superiorId'] ?? null, $subIds
            ]);
            echo json_encode(['success' => true, 'id' => $d['id'] ?? '']);
        } elseif ($method === 'DELETE' && $id) {
            $stmt = $conn->prepare("DELETE FROM supervisores WHERE id = ?");
            $stmt->execute([$id]);
            echo json_encode(['success' => true]);
        }
    } else {
        if ($method === 'GET') {
            if ($id) {
                $stmt = sqlsrv_query($conn, "SELECT * FROM supervisores WHERE id = ?", [$id]);
                $row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC);
                sqlsrv_free_stmt($stmt);
                echo json_encode($row ?: null);
            } else {
                $stmt = sqlsrv_query($conn, "SELECT * FROM supervisores ORDER BY nombre");
                $rows = [];
                while ($r = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC)) $rows[] = $r;
                sqlsrv_free_stmt($stmt);
                echo json_encode($rows);
            }
        } elseif ($method === 'POST') {
            $d = getJsonInput();
            $id = $d['id'] ?? uniqid('s_');
            $subIds = isset($d['subordinadosIds']) ? (is_array($d['subordinadosIds']) ? implode(',', $d['subordinadosIds']) : $d['subordinadosIds']) : '';
            $params = [$id, $d['nombre'] ?? '', $d['codigo'] ?? '', $d['zona'] ?? '', $d['cargo'] ?? 'coach', $d['superiorId'] ?? null, $subIds];
            $stmt = sqlsrv_query($conn, "INSERT INTO supervisores (id,nombre,codigo,zona,cargo,superiorId,subordinadosIds) VALUES (?,?,?,?,?,?,?)", $params);
            if ($stmt === false) {
                http_response_code(500);
                echo json_encode(['error' => print_r(sqlsrv_errors(), true)]);
                exit;
            }
            sqlsrv_free_stmt($stmt);
            echo json_encode(['success' => true, 'id' => $id]);
        } elseif ($method === 'DELETE' && $id) {
            $stmt = sqlsrv_query($conn, "DELETE FROM supervisores WHERE id = ?", [$id]);
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
