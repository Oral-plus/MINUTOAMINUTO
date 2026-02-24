<?php
declare(strict_types=1);

define('DB_HOST', getenv('DB_HOST') ?: '192.168.2.244');
define('DB_NAME', getenv('DB_NAME') ?: 'minuto_a_minuto');
define('DB_USER', getenv('DB_USER') ?: 'sa');
define('DB_PASS', getenv('DB_PASS') ?: 'Sky2022*!');
define('DB_PORT', (int)(getenv('DB_PORT') ?: '1433'));
define('DB_CHARSET', 'UTF-8');
define('APP_DEBUG', (getenv('APP_DEBUG') ?: '0') === '1');

function getDbConnection()
{
    static $cached = null;
    if ($cached !== null) {
        return $cached;
    }

    $connectionInfo = [
        'Database' => DB_NAME,
        'UID' => DB_USER,
        'PWD' => DB_PASS,
        'CharacterSet' => DB_CHARSET,
        'TrustServerCertificate' => true,
        'Encrypt' => false,
    ];

    if (function_exists('sqlsrv_connect')) {
        $conn = sqlsrv_connect(DB_HOST . ',' . DB_PORT, $connectionInfo);
        if ($conn === false) {
            throw new RuntimeException('No fue posible conectar con SQL Server (sqlsrv).');
        }
        $cached = $conn;
        return $cached;
    }

    if (class_exists('PDO')) {
        try {
            $dsn = 'sqlsrv:Server=' . DB_HOST . ',' . DB_PORT . ';Database=' . DB_NAME;
            $options = [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            ];
            if (defined('PDO::SQLSRV_ATTR_ENCODING') && defined('PDO::SQLSRV_ENCODING_UTF8')) {
                $options[PDO::SQLSRV_ATTR_ENCODING] = PDO::SQLSRV_ENCODING_UTF8;
            }
            $conn = new PDO($dsn, DB_USER, DB_PASS, $options);
            $cached = $conn;
            return $cached;
        } catch (Throwable $e) {
            throw new RuntimeException('No fue posible conectar con SQL Server (PDO).');
        }
    }

    throw new RuntimeException('No existe driver SQL Server (sqlsrv ni pdo_sqlsrv).');
}

function testDatabaseConnection(): array
{
    try {
        $conn = getDbConnection();
        $rows = dbQueryAll($conn, 'SELECT @@VERSION AS version');
        return [
            'success' => true,
            'driver' => $conn instanceof PDO ? 'pdo_sqlsrv' : 'sqlsrv',
            'server' => DB_HOST . ':' . DB_PORT,
            'database' => DB_NAME,
            'version' => $rows[0]['version'] ?? 'unknown',
        ];
    } catch (Throwable $e) {
        return [
            'success' => false,
            'message' => APP_DEBUG ? $e->getMessage() : 'Error de conexión a base de datos.',
        ];
    }
}

function dbBegin($conn): void
{
    if ($conn instanceof PDO) {
        if (!$conn->inTransaction()) {
            $conn->beginTransaction();
        }
        return;
    }
    if (!sqlsrv_begin_transaction($conn)) {
        throwSqlsrv('No fue posible iniciar la transacción.');
    }
}

function dbCommit($conn): void
{
    if ($conn instanceof PDO) {
        if ($conn->inTransaction()) {
            $conn->commit();
        }
        return;
    }
    if (!sqlsrv_commit($conn)) {
        throwSqlsrv('No fue posible confirmar la transacción.');
    }
}

function dbRollback($conn): void
{
    if ($conn instanceof PDO) {
        if ($conn->inTransaction()) {
            $conn->rollBack();
        }
        return;
    }
    @sqlsrv_rollback($conn);
}

function dbExecute($conn, string $sql, array $params = []): int
{
    if ($conn instanceof PDO) {
        $stmt = $conn->prepare($sql);
        $stmt->execute($params);
        return $stmt->rowCount();
    }
    $stmt = sqlsrv_query($conn, $sql, $params);
    if ($stmt === false) {
        throwSqlsrv('Error al ejecutar sentencia SQL.');
    }
    $rows = sqlsrv_rows_affected($stmt);
    sqlsrv_free_stmt($stmt);
    return is_int($rows) ? $rows : 0;
}

function dbQueryAll($conn, string $sql, array $params = []): array
{
    if ($conn instanceof PDO) {
        $stmt = $conn->prepare($sql);
        $stmt->execute($params);
        return normalizeRows($stmt->fetchAll(PDO::FETCH_ASSOC));
    }
    $stmt = sqlsrv_query($conn, $sql, $params);
    if ($stmt === false) {
        throwSqlsrv('Error al consultar datos.');
    }
    $rows = [];
    while ($row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC)) {
        $rows[] = normalizeRow($row);
    }
    sqlsrv_free_stmt($stmt);
    return $rows;
}

function dbQueryOne($conn, string $sql, array $params = []): ?array
{
    $rows = dbQueryAll($conn, $sql, $params);
    return $rows[0] ?? null;
}

function normalizeRows(array $rows): array
{
    $out = [];
    foreach ($rows as $row) {
        $out[] = normalizeRow($row);
    }
    return $out;
}

function normalizeRow(array $row): array
{
    foreach ($row as $key => $value) {
        if ($value instanceof DateTimeInterface) {
            $row[$key] = $value->format('Y-m-d H:i:s');
        }
    }
    return $row;
}

function throwSqlsrv(string $prefix): void
{
    $errors = function_exists('sqlsrv_errors') ? sqlsrv_errors(SQLSRV_ERR_ERRORS) : null;
    if (APP_DEBUG && is_array($errors) && !empty($errors)) {
        $parts = [];
        foreach ($errors as $err) {
            $parts[] = trim((string)($err['message'] ?? ''));
        }
        throw new RuntimeException($prefix . ' ' . implode(' | ', $parts));
    }
    throw new RuntimeException($prefix);
}
