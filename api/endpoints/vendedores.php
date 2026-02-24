<?php
declare(strict_types=1);

function handleVendedores($conn, string $method, ?string $id): void
{
    if ($method === 'GET') {
        if ($id) {
            $row = dbQueryOne($conn, 'SELECT * FROM vendedores WHERE id = ?', [$id]);
            jsonResponse($row ?: null);
            return;
        }
        $rows = dbQueryAll($conn, 'SELECT * FROM vendedores ORDER BY nombre');
        jsonResponse($rows);
        return;
    }

    if ($method === 'POST') {
        $d = getJsonInput();
        $vid = optionalString($d, 'id', '');
        if ($vid === '') {
            $vid = uniqid('v_', false);
        }

        $payload = [
            requiredString($d, 'nombre'),
            requiredString($d, 'codigo'),
            requiredString($d, 'zona'),
            requiredString($d, 'coachId'),
            (int)($d['geolocalizacionActiva'] ?? 0),
            ($d['horaInicioJornada'] ?? null),
            (float)($d['presupuestoMensual'] ?? 0),
            (float)($d['presupuestoDiario'] ?? 0),
        ];

        dbBegin($conn);
        try {
            $exists = dbQueryOne($conn, 'SELECT COUNT(1) AS total FROM vendedores WHERE id = ?', [$vid]);
            $alreadyExists = ((int)($exists['total'] ?? 0)) > 0;
            if ($alreadyExists) {
                dbExecute(
                    $conn,
                    'UPDATE vendedores SET nombre=?,codigo=?,zona=?,coachId=?,geolocalizacionActiva=?,horaInicioJornada=?,presupuestoMensual=?,presupuestoDiario=? WHERE id=?',
                    array_merge($payload, [$vid])
                );
                dbCommit($conn);
                jsonResponse(['success' => true, 'id' => $vid, 'mode' => 'updated']);
                return;
            }

            dbExecute(
                $conn,
                'INSERT INTO vendedores (id,nombre,codigo,zona,coachId,geolocalizacionActiva,horaInicioJornada,presupuestoMensual,presupuestoDiario) VALUES (?,?,?,?,?,?,?,?,?)',
                array_merge([$vid], $payload)
            );
            dbCommit($conn);
            jsonResponse(['success' => true, 'id' => $vid, 'mode' => 'inserted']);
            return;
        } catch (Throwable $e) {
            dbRollback($conn);
            throw $e;
        }
    }

    if ($method === 'DELETE') {
        if (!$id) {
            throw new InvalidArgumentException('id requerido');
        }
        dbExecute($conn, 'DELETE FROM vendedores WHERE id = ?', [$id]);
        jsonResponse(['success' => true, 'id' => $id]);
        return;
    }

    jsonResponse(['success' => false, 'error' => 'Método no permitido'], 405);
}
