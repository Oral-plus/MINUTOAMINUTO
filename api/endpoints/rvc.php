<?php
declare(strict_types=1);

function handleRvc($conn, string $method, ?string $id): void
{
    if ($method === 'GET') {
        $fecha = $_GET['fecha'] ?? date('Y-m-d');
        $vendedorId = isset($_GET['vendedorId']) ? trim((string)$_GET['vendedorId']) : '';

        if ($vendedorId !== '') {
            $row = dbQueryOne(
                $conn,
                'SELECT * FROM rvc WHERE vendedorId = ? AND fecha = ?',
                [$vendedorId, $fecha]
            );
            jsonResponse($row ?: null);
            return;
        }

        $rows = dbQueryAll($conn, 'SELECT * FROM rvc WHERE fecha = ?', [$fecha]);
        jsonResponse($rows);
        return;
    }

    if ($method === 'POST') {
        $d = getJsonInput();
        $rid = optionalString($d, 'id', '');
        if ($rid === '') {
            $rid = uniqid('rvc_', false);
        }

        $payload = [
            requiredString($d, 'vendedorId'),
            requiredString($d, 'fecha'),
            optionalString($d, 'zona', ''),
            (int)($d['clientesVisitados'] ?? 0),
            (int)($d['clientes60Visitados'] ?? 0),
            (int)($d['clientesPerdidosVisitados'] ?? 0),
            (float)($d['ventaTotal'] ?? 0),
            (float)($d['recaudoTotal'] ?? 0),
            optionalString($d, 'clientesNoVisitados', ''),
            (int)($d['descuentosAplicados'] ?? 0),
        ];

        dbBegin($conn);
        try {
            $exists = dbQueryOne($conn, 'SELECT COUNT(1) AS total FROM rvc WHERE id = ?', [$rid]);
            if (((int)($exists['total'] ?? 0)) > 0) {
                dbExecute(
                    $conn,
                    'UPDATE rvc SET vendedorId=?,fecha=?,zona=?,clientesVisitados=?,clientes60Visitados=?,clientesPerdidosVisitados=?,ventaTotal=?,recaudoTotal=?,clientesNoVisitados=?,descuentosAplicados=? WHERE id=?',
                    array_merge($payload, [$rid])
                );
                dbCommit($conn);
                jsonResponse(['success' => true, 'id' => $rid, 'mode' => 'updated']);
                return;
            }

            dbExecute(
                $conn,
                'INSERT INTO rvc (id,vendedorId,fecha,zona,clientesVisitados,clientes60Visitados,clientesPerdidosVisitados,ventaTotal,recaudoTotal,clientesNoVisitados,descuentosAplicados) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
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

    jsonResponse(['success' => false, 'error' => 'Método no permitido'], 405);
}
