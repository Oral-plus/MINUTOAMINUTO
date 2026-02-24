<?php
declare(strict_types=1);

define('DB_HOST', getenv('DB_HOST') ?: '192.168.2.244');
define('DB_NAME', getenv('DB_NAME') ?: 'minuto_a_minuto');
define('DB_USER', getenv('DB_USER') ?: 'sa');
define('DB_PASS', getenv('DB_PASS') ?: 'Sky2022*!');
define('DB_PORT', (int)(getenv('DB_PORT') ?: '1433'));
define('DB_SERVER', getenv('DB_SERVER') ?: '');
define('DB_LOGIN_TIMEOUT', (int)(getenv('DB_LOGIN_TIMEOUT') ?: '8'));
define('DB_QUERY_TIMEOUT', (int)(getenv('DB_QUERY_TIMEOUT') ?: '20'));
define('DB_ENCRYPT', envBool('DB_ENCRYPT', false));
define('DB_TRUST_SERVER_CERT', envBool('DB_TRUST_SERVER_CERT', true));
define('DB_CHARSET', 'UTF-8');
define('APP_DEBUG', (getenv('APP_DEBUG') ?: '0') === '1');

function envBool(string $name, bool $default): bool
{
    $raw = getenv($name);
    if ($raw === false || trim((string)$raw) === '') {
        return $default;
    }
    $value = strtolower(trim((string)$raw));
    if (in_array($value, ['1', 'true', 'yes', 'y', 'on'], true)) {
        return true;
    }
    if (in_array($value, ['0', 'false', 'no', 'n', 'off'], true)) {
        return false;
    }
    return $default;
}

function buildServerName(): string
{
    if (DB_SERVER !== '') {
        return DB_SERVER;
    }

    // Si el host ya trae instancia o puerto explícito, no forzar formato.
    if (strpos(DB_HOST, '\\') !== false || strpos(DB_HOST, ',') !== false) {
        return DB_HOST;
    }

    return DB_HOST . ',' . DB_PORT;
}

function isPrivateHost(string $host): bool
{
    $h = trim($host);
    if ($h === '' || $h === 'localhost') {
        return true;
    }
    if (strpos($h, '\\') !== false) {
        $h = explode('\\', $h, 2)[0];
    }
    if (strpos($h, ',') !== false) {
        $h = explode(',', $h, 2)[0];
    }
    if (filter_var($h, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) === false) {
        return false;
    }
    $long = ip2long($h);
    if ($long === false) {
        return false;
    }
    $privateRanges = [
        ['10.0.0.0', '10.255.255.255'],
        ['172.16.0.0', '172.31.255.255'],
        ['192.168.0.0', '192.168.255.255'],
        ['127.0.0.0', '127.255.255.255'],
    ];
    foreach ($privateRanges as [$start, $end]) {
        if ($long >= ip2long($start) && $long <= ip2long($end)) {
            return true;
        }
    }
    return false;
}

function tcpProbe(string $host, int $port, float $timeout = 4.0): array
{
    $target = $host;
    if (strpos($target, '\\') !== false) {
        $target = explode('\\', $target, 2)[0];
    }
    if (strpos($target, ',') !== false) {
        $target = explode(',', $target, 2)[0];
    }
    $target = trim($target);
    if ($target === '') {
        return ['ok' => false, 'message' => 'Host vacío'];
    }

    $errno = 0;
    $errstr = '';
    $socket = @fsockopen($target, $port, $errno, $errstr, $timeout);
    if ($socket === false) {
        return [
            'ok' => false,
            'message' => trim($errstr) !== '' ? $errstr : 'No se pudo abrir socket TCP',
            'errno' => $errno,
        ];
    }
    fclose($socket);
    return ['ok' => true];
}

function sqlsrvErrorMessage(): string
{
    if (!function_exists('sqlsrv_errors')) {
        return '';
    }
    $errors = sqlsrv_errors(SQLSRV_ERR_ERRORS);
    if (!is_array($errors) || empty($errors)) {
        return '';
    }
    $parts = [];
    foreach ($errors as $err) {
        $parts[] = trim((string)($err['message'] ?? ''));
    }
    return implode(' | ', array_filter($parts));
}

function getDbConnection()
{
    static $cached = null;
    if ($cached !== null) {
        return $cached;
    }

    $serverName = buildServerName();
    $connectionInfo = [
        'Database' => DB_NAME,
        'UID' => DB_USER,
        'PWD' => DB_PASS,
        'CharacterSet' => DB_CHARSET,
        'TrustServerCertificate' => DB_TRUST_SERVER_CERT,
        'Encrypt' => DB_ENCRYPT,
        'LoginTimeout' => DB_LOGIN_TIMEOUT,
        'QueryTimeout' => DB_QUERY_TIMEOUT,
    ];

    if (function_exists('sqlsrv_connect')) {
        $conn = sqlsrv_connect($serverName, $connectionInfo);
        if ($conn === false) {
            $details = sqlsrvErrorMessage();
            if (APP_DEBUG && $details !== '') {
                throw new RuntimeException('No fue posible conectar con SQL Server (sqlsrv). ' . $details);
            }
            throw new RuntimeException('No fue posible conectar con SQL Server (sqlsrv).');
        }
        $cached = $conn;
        return $cached;
    }

    if (class_exists('PDO')) {
        try {
            $dsn = 'sqlsrv:Server=' . $serverName . ';Database=' . DB_NAME;
            $dsn .= ';Encrypt=' . (DB_ENCRYPT ? 'yes' : 'no');
            $dsn .= ';TrustServerCertificate=' . (DB_TRUST_SERVER_CERT ? 'yes' : 'no');
            $dsn .= ';LoginTimeout=' . DB_LOGIN_TIMEOUT;
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
            if (APP_DEBUG) {
                throw new RuntimeException('No fue posible conectar con SQL Server (PDO). ' . $e->getMessage());
            }
            throw new RuntimeException('No fue posible conectar con SQL Server (PDO).');
        }
    }

    throw new RuntimeException('No existe driver SQL Server (sqlsrv ni pdo_sqlsrv).');
}

function testDatabaseConnection(): array
{
    $serverName = buildServerName();
    $probe = tcpProbe($serverName, DB_PORT);

    try {
        $conn = getDbConnection();
        $rows = dbQueryAll($conn, 'SELECT @@VERSION AS version');
        $response = [
            'success' => true,
            'driver' => $conn instanceof PDO ? 'pdo_sqlsrv' : 'sqlsrv',
            'server' => $serverName,
            'host' => DB_HOST,
            'port' => DB_PORT,
            'database' => DB_NAME,
            'encrypt' => DB_ENCRYPT,
            'trustServerCertificate' => DB_TRUST_SERVER_CERT,
            'tcpProbe' => $probe,
            'version' => $rows[0]['version'] ?? 'unknown',
        ];
        if (isPrivateHost(DB_HOST)) {
            $response['networkHint'] = 'DB_HOST es privado/local; desde Render solo funcionará si la red expone ese SQL Server públicamente (NAT/VPN/túnel).';
        }
        return $response;
    } catch (Throwable $e) {
        $response = [
            'success' => false,
            'message' => APP_DEBUG ? $e->getMessage() : 'Error de conexión a base de datos.',
            'server' => $serverName,
            'host' => DB_HOST,
            'port' => DB_PORT,
            'database' => DB_NAME,
            'encrypt' => DB_ENCRYPT,
            'trustServerCertificate' => DB_TRUST_SERVER_CERT,
            'tcpProbe' => $probe,
        ];
        if (isPrivateHost(DB_HOST)) {
            $response['networkHint'] = 'DB_HOST es privado/local; Render (nube) no accede a 192.168.x.x salvo túnel o IP pública con puerto abierto.';
        }
        return $response;
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
