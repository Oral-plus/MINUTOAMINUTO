<?php
declare(strict_types=1);

function handleSupervisores($conn, string $method, ?string $id): void
{
    if ($method === 'GET') {
        if ($id) {
            $row = dbQueryOne($conn, 'SELECT * FROM supervisores WHERE id = ?', [$id]);
            jsonResponse($row ?: null);
            return;
        }
        $rows = dbQueryAll($conn, 'SELECT * FROM supervisores ORDER BY nombre');
        jsonResponse($rows);
        return;
    }

    if ($method === 'POST') {
        $d = getJsonInput();
        $sid = optionalString($d, 'id', '');
        if ($sid === '') {
            $sid = uniqid('s_', false);
        }

        $subIds = isset($d['subordinadosIds'])
            ? (is_array($d['subordinadosIds']) ? implode(',', $d['subordinadosIds']) : (string)$d['subordinadosIds'])
            : '';

        $payload = [
            requiredString($d, 'nombre'),
            requiredString($d, 'codigo'),
            requiredString($d, 'zona'),
            optionalString($d, 'cargo', 'coach'),
            ($d['superiorId'] ?? null),
            $subIds,
        ];

        dbBegin($conn);
        try {
            $exists = dbQueryOne($conn, 'SELECT COUNT(1) AS total FROM supervisores WHERE id = ?', [$sid]);
            $alreadyExists = ((int)($exists['total'] ?? 0)) > 0;
            if ($alreadyExists) {
                dbExecute(
                    $conn,
                    'UPDATE supervisores SET nombre=?,codigo=?,zona=?,cargo=?,superiorId=?,subordinadosIds=? WHERE id=?',
                    array_merge($payload, [$sid])
                );
                dbCommit($conn);
                jsonResponse(['success' => true, 'id' => $sid, 'mode' => 'updated']);
                return;
            }

            dbExecute(
                $conn,
                'INSERT INTO supervisores (id,nombre,codigo,zona,cargo,superiorId,subordinadosIds) VALUES (?,?,?,?,?,?,?)',
                array_merge([$sid], $payload)
            );
            dbCommit($conn);
            jsonResponse(['success' => true, 'id' => $sid, 'mode' => 'inserted']);
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
        dbExecute($conn, 'DELETE FROM supervisores WHERE id = ?', [$id]);
        jsonResponse(['success' => true, 'id' => $id]);
        return;
    }

    jsonResponse(['success' => false, 'error' => 'Método no permitido'], 405);
}
