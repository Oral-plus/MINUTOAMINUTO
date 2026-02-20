<?php
// No permitir acceso directo
if (basename($_SERVER['SCRIPT_FILENAME'] ?? '') === 'config.php') {
    http_response_code(403);
    exit('Acceso denegado');
}
session_start();
require_once __DIR__ . '/../api/config/database.php';

// Credenciales del portal admin (cambiar en producción)
define('ADMIN_USER', getenv('ADMIN_USER') ?: 'admin');
define('ADMIN_PASS', getenv('ADMIN_PASS') ?: 'minuto2025');

function isLoggedIn() {
    return !empty($_SESSION['admin_logged']);
}

function requireLogin() {
    if (!isLoggedIn()) {
        header('Location: index.php');
        exit;
    }
}

function formatDate($val) {
    if ($val instanceof DateTime) return $val->format('Y-m-d');
    return $val;
}

function formatDateTime($val) {
    if ($val instanceof DateTime) return $val->format('Y-m-d H:i');
    return $val;
}

function dbQuery($conn, $sql, $params = []) {
    if ($conn instanceof PDO) {
        $stmt = empty($params) ? $conn->query($sql) : $conn->prepare($sql);
        if (!empty($params)) $stmt->execute($params);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } else {
        $stmt = empty($params) ? sqlsrv_query($conn, $sql) : sqlsrv_query($conn, $sql, $params);
        if ($stmt === false) throw new Exception(print_r(sqlsrv_errors(), true));
        $rows = [];
        while ($r = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC)) {
            foreach (['fecha', 'horaInicio', 'horaFin', 'fechaCreacion', 'timestamp'] as $f) {
                if (isset($r[$f]) && $r[$f] instanceof DateTime) {
                    $r[$f] = in_array($f, ['horaInicio','horaFin','fechaCreacion','timestamp']) ? $r[$f]->format('Y-m-d H:i:s') : $r[$f]->format('Y-m-d');
                }
            }
            $rows[] = $r;
        }
        sqlsrv_free_stmt($stmt);
    }
    return $rows;
}
