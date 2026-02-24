<?php
declare(strict_types=1);

function handleUbicaciones($conn, string $method, ?string $id): void
{
    if ($method !== 'POST') {
        jsonResponse(['success' => false, 'error' => 'Método no permitido'], 405);
        return;
    }

    $d = getJsonInput();
    $uid = optionalString($d, 'id', '');
    if ($uid === '') {
        $uid = uniqid('ub_', false);
    }

    $payload = [
        requiredString($d, 'vendedorId'),
        optionalString($d, 'fecha', date('Y-m-d')),
        (float)($d['latitud'] ?? 0),
        (float)($d['longitud'] ?? 0),
        optionalString($d, 'timestamp', date('Y-m-d H:i:s')),
    ];

    dbBegin($conn);
    try {
        $exists = dbQueryOne($conn, 'SELECT COUNT(1) AS total FROM ubicaciones WHERE id = ?', [$uid]);
        if (((int)($exists['total'] ?? 0)) > 0) {
            dbExecute(
                $conn,
                'UPDATE ubicaciones SET vendedorId=?,fecha=?,latitud=?,longitud=?,[timestamp]=? WHERE id=?',
                array_merge($payload, [$uid])
            );
            dbCommit($conn);
            jsonResponse(['success' => true, 'id' => $uid, 'mode' => 'updated']);
            return;
        }

        dbExecute(
            $conn,
            'INSERT INTO ubicaciones (id,vendedorId,fecha,latitud,longitud,[timestamp]) VALUES (?,?,?,?,?,?)',
            array_merge([$uid], $payload)
        );
        dbCommit($conn);
        jsonResponse(['success' => true, 'id' => $uid, 'mode' => 'inserted']);
    } catch (Throwable $e) {
        dbRollback($conn);
        throw $e;
    }
}
