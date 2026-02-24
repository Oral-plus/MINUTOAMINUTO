<?php
declare(strict_types=1);

function handlePpvc($conn, string $method, ?string $id): void
{
    if ($method === 'GET') {
        $fecha = $_GET['fecha'] ?? date('Y-m-d');
        $vendedorId = isset($_GET['vendedorId']) ? trim((string)$_GET['vendedorId']) : '';

        if ($vendedorId !== '') {
            $row = dbQueryOne(
                $conn,
                'SELECT * FROM ppvc WHERE vendedorId = ? AND fecha = ?',
                [$vendedorId, $fecha]
            );
            jsonResponse($row ?: null);
            return;
        }

        $rows = dbQueryAll($conn, 'SELECT * FROM ppvc WHERE fecha = ?', [$fecha]);
        jsonResponse($rows);
        return;
    }

    if ($method === 'POST') {
        $d = getJsonInput();
        $pid = optionalString($d, 'id', '');
        if ($pid === '') {
            $pid = uniqid('ppvc_', false);
        }

        $payload = [
            requiredString($d, 'vendedorId'),
            requiredString($d, 'fecha'),
            optionalString($d, 'zona', ''),
            (int)($d['clientesProgramados'] ?? 0),
            optionalString($d, 'clientes60Ids', ''),
            optionalString($d, 'clientesPerdidosIds', ''),
            (float)($d['metaVenta'] ?? 0),
            (float)($d['metaRecaudo'] ?? 0),
            (int)($d['programado2DiasAntes'] ?? 0),
        ];

        dbBegin($conn);
        try {
            $exists = dbQueryOne($conn, 'SELECT COUNT(1) AS total FROM ppvc WHERE id = ?', [$pid]);
            if (((int)($exists['total'] ?? 0)) > 0) {
                dbExecute(
                    $conn,
                    'UPDATE ppvc SET vendedorId=?,fecha=?,zona=?,clientesProgramados=?,clientes60Ids=?,clientesPerdidosIds=?,metaVenta=?,metaRecaudo=?,programado2DiasAntes=? WHERE id=?',
                    array_merge($payload, [$pid])
                );
                dbCommit($conn);
                jsonResponse(['success' => true, 'id' => $pid, 'mode' => 'updated']);
                return;
            }

            dbExecute(
                $conn,
                'INSERT INTO ppvc (id,vendedorId,fecha,zona,clientesProgramados,clientes60Ids,clientesPerdidosIds,metaVenta,metaRecaudo,programado2DiasAntes) VALUES (?,?,?,?,?,?,?,?,?,?)',
                array_merge([$pid], $payload)
            );
            dbCommit($conn);
            jsonResponse(['success' => true, 'id' => $pid, 'mode' => 'inserted']);
            return;
        } catch (Throwable $e) {
            dbRollback($conn);
            throw $e;
        }
    }

    jsonResponse(['success' => false, 'error' => 'Método no permitido'], 405);
}
