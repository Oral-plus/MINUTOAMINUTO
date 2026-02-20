<?php
// config/database.php - Conexión SQL Server para Minuto a Minuto
// En producción: usar DB_HOST, DB_NAME, DB_USER, DB_PASS, DB_PORT como variables de entorno

define('DB_HOST', getenv('DB_HOST') ?: '192.168.2.244');
define('DB_NAME', getenv('DB_NAME') ?: 'minuto_a_minuto');
define('DB_USER', getenv('DB_USER') ?: 'sa');
define('DB_PASS', getenv('DB_PASS') ?: 'Sky2022*!');
define('DB_PORT', (int)(getenv('DB_PORT') ?: '1433'));
define('DB_CHARSET', 'UTF-8');

function getDbConnection() {
    $connectionInfo = array(
        "Database" => DB_NAME,
        "UID" => DB_USER,
        "PWD" => DB_PASS,
        "CharacterSet" => DB_CHARSET,
        "TrustServerCertificate" => true,
        "Encrypt" => false
    );
    
    if (function_exists('sqlsrv_connect')) {
        $conn = sqlsrv_connect(DB_HOST . ',' . DB_PORT, $connectionInfo);
        
        if ($conn === false) {
            $errors = sqlsrv_errors();
            error_log("Error SQL Server: " . print_r($errors, true));
            throw new Exception("Error de conexión a la base de datos.");
        }
        return $conn;
    } else {
        try {
            $dsn = "sqlsrv:Server=" . DB_HOST . "," . DB_PORT . ";Database=" . DB_NAME;
            $conn = new PDO($dsn, DB_USER, DB_PASS, array(
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::SQLSRV_ATTR_ENCODING => PDO::SQLSRV_ENCODING_UTF8
            ));
            return $conn;
        } catch (PDOException $e) {
            error_log("Error PDO: " . $e->getMessage());
            throw new Exception("Error de conexión a la base de datos.");
        }
    }
}

function testDatabaseConnection() {
    try {
        $conn = getDbConnection();
        
        if ($conn instanceof PDO) {
            $stmt = $conn->query("SELECT @@VERSION as version");
            $result = $stmt->fetch(PDO::FETCH_ASSOC);
            return ['success' => true, 'message' => 'Conexión exitosa (PDO)', 'version' => $result['version']];
        } else {
            $stmt = sqlsrv_query($conn, "SELECT @@VERSION as version");
            if ($stmt === false) throw new Exception(print_r(sqlsrv_errors(), true));
            $row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC);
            sqlsrv_free_stmt($stmt);
            return ['success' => true, 'message' => 'Conexión exitosa (sqlsrv)', 'version' => $row['version']];
        }
    } catch (Exception $e) {
        return ['success' => false, 'message' => $e->getMessage()];
    }
}
