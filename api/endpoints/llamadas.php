<?php
declare(strict_types=1);

function handleLlamadas($conn, string $method, ?string $id): void
{
    if ($method === 'GET') {
        $desde = $_GET['desde'] ?? date('Y-m-d');
        $hasta = $_GET['hasta'] ?? date('Y-m-d');
        $zona = isset($_GET['zona']) ? trim((string)$_GET['zona']) : '';
        $contactado = isset($_GET['nombreContactado']) ? trim((string)$_GET['nombreContactado']) : '';

        $sql = 'SELECT * FROM registro_llamadas WHERE fecha >= ? AND fecha <= ?';
        $params = [$desde, $hasta];
        if ($zona !== '') {
            $sql .= ' AND zona = ?';
            $params[] = $zona;
        }
        if ($contactado !== '') {
            $sql .= ' AND nombreContactado = ?';
            $params[] = $contactado;
        }
        $sql .= ' ORDER BY horaInicio DESC';
        $rows = dbQueryAll($conn, $sql, $params);
        jsonResponse($rows);
        return;
    }

    if ($method === 'POST') {
        $d = getJsonInput();
        $rid = optionalString($d, 'id', '');
        if ($rid === '') {
            $rid = uniqid('llamada_', false);
        }

        $payload = [
            requiredString($d, 'fecha'),
            requiredString($d, 'horaInicio'),
            requiredString($d, 'horaFin'),
            (int)($d['duracionMinutos'] ?? 0),
            requiredString($d, 'tipoLlamada'),
            requiredString($d, 'cargoLider'),
            requiredString($d, 'zona'),
            requiredString($d, 'nombreLider'),
            requiredString($d, 'nombreContactado'),
            (int)($d['clientesProgramados'] ?? 0),
            (int)($d['clientesVisitados'] ?? 0),
            (float)($d['ventaDia'] ?? 0),
            (float)($d['recaudoDia'] ?? 0),
            (int)($d['cumplioMeta'] ?? 0),
            (int)($d['coincidenciaPpvcRvc'] ?? 0),
            (int)($d['conversion60'] ?? 0),
            (int)($d['recuperacionPerdidos'] ?? 0),
            optionalString($d, 'observaciones', ''),
            (int)($d['confirmacionVeracidad'] ?? 0),
            ($d['rutaGrabacion'] ?? null),
            ($d['transcripcionTexto'] ?? null),
        ];

        dbBegin($conn);
        try {
            $exists = dbQueryOne($conn, 'SELECT COUNT(1) AS total FROM registro_llamadas WHERE id = ?', [$rid]);
            $alreadyExists = ((int)($exists['total'] ?? 0)) > 0;
            if ($alreadyExists) {
                dbExecute(
                    $conn,
                    'UPDATE registro_llamadas SET fecha=?,horaInicio=?,horaFin=?,duracionMinutos=?,tipoLlamada=?,cargoLider=?,zona=?,nombreLider=?,nombreContactado=?,clientesProgramados=?,clientesVisitados=?,ventaDia=?,recaudoDia=?,cumplioMeta=?,coincidenciaPpvcRvc=?,conversion60=?,recuperacionPerdidos=?,observaciones=?,confirmacionVeracidad=?,rutaGrabacion=?,transcripcionTexto=? WHERE id=?',
                    array_merge($payload, [$rid])
                );
                dbCommit($conn);
                jsonResponse(['success' => true, 'id' => $rid, 'mode' => 'updated']);
                return;
            }

            dbExecute(
                $conn,
                'INSERT INTO registro_llamadas (id,fecha,horaInicio,horaFin,duracionMinutos,tipoLlamada,cargoLider,zona,nombreLider,nombreContactado,clientesProgramados,clientesVisitados,ventaDia,recaudoDia,cumplioMeta,coincidenciaPpvcRvc,conversion60,recuperacionPerdidos,observaciones,confirmacionVeracidad,rutaGrabacion,transcripcionTexto) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
                array_merge([$rid], $payload)
            );
            dbCommit($conn);
            jsonResponse(['success' => true, 'id' => $rid, 'mode' => 'inserted']);
            return;
        } catch (Throwable $e) {
            dbRollback($conn);
            throw $e;
        }
    }

    if ($method === 'PATCH') {
        if (!$id) {
            throw new InvalidArgumentException('id requerido');
        }
        $d = getJsonInput();
        $allowed = ['observaciones', 'rutaGrabacion', 'transcripcionTexto'];
        $sets = [];
        $params = [];
        foreach ($allowed as $field) {
            if (array_key_exists($field, $d)) {
                $sets[] = "$field = ?";
                $params[] = $d[$field];
            }
        }
        if (empty($sets)) {
            jsonResponse(['success' => false, 'message' => 'Sin campos para actualizar'], 400);
            return;
        }
        $params[] = $id;
        $rows = dbExecute(
            $conn,
            'UPDATE registro_llamadas SET ' . implode(', ', $sets) . ' WHERE id = ?',
            $params
        );
        jsonResponse(['success' => true, 'id' => $id, 'rows' => $rows]);
        return;
    }

    jsonResponse(['success' => false, 'error' => 'Método no permitido'], 405);
}
