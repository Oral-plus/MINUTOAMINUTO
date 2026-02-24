<?php
declare(strict_types=1);

function handleAlertas($conn, string $method, ?string $id): void
{
    if ($method === 'GET') {
        $resueltas = isset($_GET['resuelta']) ? (int)$_GET['resuelta'] : 0;
        $rows = dbQueryAll(
            $conn,
            'SELECT * FROM alertas WHERE resuelta = ? ORDER BY fecha DESC',
            [$resueltas]
        );
        foreach ($rows as &$row) {
            if (isset($row['fecha'])) {
                $row['fecha'] = str_replace(' ', 'T', (string)$row['fecha']);
            }
        }
        jsonResponse($rows);
        return;
    }

    if ($method === 'POST') {
        $d = getJsonInput();
        $aid = optionalString($d, 'id', '');
        if ($aid === '') {
            $aid = uniqid('alerta_', false);
        }
        $payload = [
            requiredString($d, 'tipo'),
            requiredString($d, 'fecha'),
            requiredString($d, 'mensaje'),
            ($d['vendedorId'] ?? null),
            ($d['supervisorId'] ?? null),
            optionalString($d, 'zona', ''),
            (int)($d['resuelta'] ?? 0),
        ];

        dbBegin($conn);
        try {
            $exists = dbQueryOne($conn, 'SELECT COUNT(1) AS total FROM alertas WHERE id = ?', [$aid]);
            if (((int)($exists['total'] ?? 0)) > 0) {
                dbExecute(
                    $conn,
                    'UPDATE alertas SET tipo=?,fecha=?,mensaje=?,vendedorId=?,supervisorId=?,zona=?,resuelta=? WHERE id=?',
                    array_merge($payload, [$aid])
                );
                dbCommit($conn);
                jsonResponse(['success' => true, 'id' => $aid, 'mode' => 'updated']);
                return;
            }

            dbExecute(
                $conn,
                'INSERT INTO alertas (id,tipo,fecha,mensaje,vendedorId,supervisorId,zona,resuelta) VALUES (?,?,?,?,?,?,?,?)',
                array_merge([$aid], $payload)
            );
            dbCommit($conn);
            jsonResponse(['success' => true, 'id' => $aid, 'mode' => 'inserted']);
            return;
        } catch (Throwable $e) {
            dbRollback($conn);
            throw $e;
        }
    }

    jsonResponse(['success' => false, 'error' => 'Método no permitido'], 405);
}
